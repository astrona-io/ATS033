# Node checks for this lab. check.py runs this file with its helpers in scope.
# `sshd -T` makes the SSH server read its configuration files the way it does
# at start and print the effective global settings, one "keyword value" line
# each, in lower case. Settings inside a Match block are not global, so they
# are not in this output. AllowUsers prints one line per account.
# The files are not the running server: a reload is needed before a change
# takes effect. Two outcomes also test the running server.
import time

ALLOWED_ACCOUNTS = {'opsadmin', 'student', 'astrona'}
SSH_TEST_OPTIONS = [
    '-o', 'BatchMode=yes',
    '-o', 'PreferredAuthentications=none',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=/dev/null',
    '-o', 'ConnectTimeout=5',
]


def effective_settings():
    result = node_exec(NODE, 'sshd', '-T', success=False)
    assert result.returncode == 0, 'sshd -T rejects the configuration: ' + (result.stderr or result.stdout).strip()
    settings = {}
    for line in result.stdout.splitlines():
        keyword, _, value = line.partition(' ')
        settings.setdefault(keyword, []).append(value.strip())
    return settings


def first(settings, keyword):
    values = settings.get(keyword)
    return values[0] if values else ''


def advertised_methods(account):
    """The login methods the running server offers this account, from the client's error line."""
    result = command(['ssh', *SSH_TEST_OPTIONS, account + '@127.0.0.1', 'true'], success=False)
    for line in result.stderr.splitlines():
        if 'Permission denied (' in line:
            return line.rsplit('(', 1)[1].rstrip(').').split(',')
    return []


states = node_exec(NODE, 'systemctl', 'is-active', 'kubelet.service', 'containerd.service', 'ssh.service', success=False).stdout.split()
assert states == ['active', 'active', 'active'], 'kubelet, containerd and ssh must stay active on ' + NODE
operator_account = node_exec(NODE, 'getent', 'passwd', 'opsadmin', success=False).stdout.strip().split(':')
assert len(operator_account) == 7 and operator_account[6] == '/bin/bash', 'The opsadmin account must exist and keep the shell /bin/bash'
match_block = node_exec(NODE, 'grep', '-c', '^Match User backup', '/etc/ssh/sshd_config', success=False).stdout.strip()
assert match_block == '1', 'Keep the Match User backup block in /etc/ssh/sshd_config'

effective = effective_settings()

if wants('root-login-refused'):
    value = first(effective, 'permitrootlogin')
    assert value == 'no', 'sshd -T shows permitrootlogin ' + value + ', not no'

if wants('password-login-refused'):
    value = first(effective, 'passwordauthentication')
    assert value == 'no', 'sshd -T shows passwordauthentication ' + value + ', not no'
    assert first(effective, 'pubkeyauthentication') == 'yes', 'Key logins must stay on (pubkeyauthentication yes)'
    methods = advertised_methods('opsadmin')
    assert methods, 'The running SSH server did not answer a test login for opsadmin'
    assert 'password' not in methods, 'The running SSH server still offers password logins (' + ','.join(methods) + '): reload ssh.service'

if wants('allow-listed-accounts-only'):
    allowed = set(effective.get('allowusers', []))
    assert allowed, 'sshd -T shows no global allowusers line: every account may log in (a line inside a Match block is not global)'
    assert allowed == ALLOWED_ACCOUNTS, 'sshd -T shows allowusers ' + ' '.join(sorted(allowed)) + ', not exactly opsadmin student astrona'
    # ubuntu has a shell but is not on the list. The running server must refuse
    # it and log why, which proves that the server has loaded the list.
    for attempt in range(5):
        started = node_exec(NODE, 'date', '+%Y-%m-%d %H:%M:%S').stdout.strip()
        advertised_methods('ubuntu')
        time.sleep(1)
        log = node_exec(NODE, 'journalctl', '--unit=ssh.service', '--since=' + started, '--no-pager', '--quiet', success=False).stdout
        if 'User ubuntu from 127.0.0.1 not allowed because not listed in AllowUsers' in log:
            break
    else:
        raise AssertionError('The running SSH server does not refuse ubuntu with AllowUsers yet: reload ssh.service')
