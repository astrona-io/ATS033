# Node checks for this lab. check.py runs this file with its helpers in scope.
# The kind node has no sshd, so this parser reads the files the way sshd does:
# - Include files are read at the Include line, in sorted (lexical) order.
# - Keywords are case-insensitive and may use "Keyword value" or "Keyword=value".
# - For most keywords the first value read wins; AllowUsers lines add up.
# - A Match line starts a conditional block that runs to the next Match line or
#   to the end of the file. "Match all" ends it. Settings inside a conditional
#   block are not global. An included file never changes the caller's state.
import re

MAIN_FILE = '/etc/ssh/sshd_config'
LINE_PATTERN = re.compile(r'^(\S+?)(?:\s*=\s*|\s+)(.*)$')


def read_node_file(path):
    return node_exec(NODE, 'cat', path).stdout


def expand_include(pattern):
    if not pattern.startswith('/'):
        pattern = '/etc/ssh/' + pattern
    listing = node_exec(NODE, 'sh', '-c', 'for path in ' + pattern + '; do [ -f "$path" ] && printf "%s\\n" "$path"; done; true').stdout
    return sorted(line for line in listing.splitlines() if line)


def parse(path, global_scope, settings, allow_users, conditional_keywords):
    for raw_line in read_node_file(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith('#'):
            continue
        match = LINE_PATTERN.match(line)
        if not match:
            continue
        keyword = match.group(1).lower()
        value = match.group(2).strip()
        if keyword == 'include':
            for pattern in value.split():
                for included in expand_include(pattern):
                    parse(included, global_scope, settings, allow_users, conditional_keywords)
            continue
        if keyword == 'match':
            global_scope = value.lower() == 'all'
            continue
        if not global_scope:
            conditional_keywords.add(keyword)
            continue
        if keyword == 'allowusers':
            allow_users.extend(value.split())
        else:
            settings.setdefault(keyword, value.split()[0].lower() if value else '')


for node in (NODE, WORKER):
    states = node_exec(node, 'systemctl', 'is-active', 'kubelet.service', 'containerd.service', success=False).stdout.split()
    assert states == ['active', 'active'], 'kubelet and containerd must stay active on ' + node
operator_account = node_exec(NODE, 'getent', 'passwd', 'opsadmin', success=False).stdout.strip().split(':')
assert len(operator_account) == 7 and operator_account[6] == '/bin/bash', 'The opsadmin account must exist and keep the shell /bin/bash'

effective = {}
allowed_accounts = []
conditional_only = set()
parse(MAIN_FILE, True, effective, allowed_accounts, conditional_only)

if wants('root-login-refused'):
    value = effective.get('permitrootlogin', 'prohibit-password (default)')
    assert value == 'no', 'The first global PermitRootLogin value sshd reads is ' + value + ', not no'

if wants('password-login-refused'):
    value = effective.get('passwordauthentication', 'yes (default)')
    assert value == 'no', 'The first global PasswordAuthentication value sshd reads is ' + value + ', not no'
    assert effective.get('pubkeyauthentication', 'yes') == 'yes', 'Key logins must stay on (PubkeyAuthentication yes)'

if wants('allow-only-opsadmin'):
    if not allowed_accounts and 'allowusers' in conditional_only:
        raise AssertionError('AllowUsers appears only inside a Match block, so it is not a global setting')
    assert allowed_accounts, 'No global AllowUsers line: every account may log in'
    assert set(allowed_accounts) == {'opsadmin'}, 'The global AllowUsers list is ' + ' '.join(allowed_accounts) + ', not only opsadmin'
