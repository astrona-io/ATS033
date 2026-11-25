NOLOGIN_SHELLS = {'/usr/sbin/nologin', '/sbin/nologin', '/bin/false', '/usr/bin/false'}


def on_node(*args, success=True):
    return node_exec(NODE, *args, success=success)


def password_status(account):
    return on_node('passwd', '-S', account).stdout.split()[1]


def passwd_entry(account):
    result = on_node('getent', 'passwd', account, success=False)
    assert result.returncode == 0, 'Keep the account ' + account + '; lock it instead of deleting it'
    return result.stdout.strip().split(':')


def expiry_day(account):
    """Field 8 of /etc/shadow: the account expiry in days since 1970-01-01, or ''."""
    return on_node('getent', 'shadow', account).stdout.strip().split(':')[7]


today = int(on_node('date', '+%s').stdout.strip()) // 86400

# Guards for every outcome: departed-user still exists with its home
# directory, and pilot keeps a usable password, its shell and no expiry.
departed = passwd_entry('departed-user')
assert on_node('test', '-d', departed[5], success=False).returncode == 0, 'Keep the home directory of departed-user'
pilot = passwd_entry('pilot')
assert pilot[6] == '/bin/bash', 'Do not change the shell of pilot'
assert password_status('pilot') == 'P', 'Do not lock pilot'
assert expiry_day('pilot') == '', 'Do not set an expiry date on pilot'

if wants('departed-locked'):
    assert password_status('departed-user') == 'L', 'Lock the password of departed-user (passwd -S must show L)'
if wants('departed-expired'):
    expiry = expiry_day('departed-user')
    assert expiry != '' and int(expiry) < today, 'Set the account expiry of departed-user to a date in the past'
    # su from root skips the password but still runs the account checks, so
    # an expired account is refused even with a shell given on the command line.
    result = on_node('su', '-s', '/bin/sh', '-c', 'true', 'departed-user', success=False)
    assert result.returncode != 0, 'su to departed-user must be refused'
if wants('departed-nologin'):
    assert departed[6] in NOLOGIN_SHELLS, 'Give departed-user a nologin shell'
if wants('sshd-hardened'):
    # sshd -T prints the settings sshd reads from its files now, after every
    # Include and drop-in. The first value sshd reads for a setting wins.
    assert on_node('sshd', '-t', success=False).returncode == 0, 'The sshd configuration must stay valid (sshd -t)'
    settings = dict(line.split(' ', 1) for line in on_node('sshd', '-T').stdout.splitlines() if ' ' in line)
    assert settings.get('permitrootlogin') == 'no', 'sshd -T must show permitrootlogin no'
    assert settings.get('passwordauthentication') == 'no', 'sshd -T must show passwordauthentication no'
    # The running daemon only uses a changed file after a reload. A login
    # attempt without a key lists the methods the running daemon offers.
    probe = command(['ssh', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
                     '-o', 'ConnectTimeout=5', '-o', 'PubkeyAuthentication=no', 'pilot@127.0.0.1', 'true'], success=False)
    assert 'Permission denied (' in probe.stderr, 'The ssh service must be running and answer on 127.0.0.1'
    assert 'password' not in probe.stderr.split('Permission denied (', 1)[1], 'The running sshd still offers password logins: reload the ssh service'
