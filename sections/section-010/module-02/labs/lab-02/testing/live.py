# Node checks for this lab. check.py runs this file with its helpers in scope.
REFUSING_SHELLS = ('/usr/sbin/nologin', '/sbin/nologin', '/bin/false', '/usr/bin/false')


def account_entries():
    """Every account the system knows, as lists of the seven passwd fields."""
    lines = node_exec(NODE, 'getent', 'passwd').stdout.splitlines()
    return [line.split(':') for line in lines if line.count(':') == 6]


def account(name):
    for fields in account_entries():
        if fields[0] == name:
            return fields
    return None


def password_status(name):
    return node_exec(NODE, 'passwd', '-S', name).stdout.split()[1]


for node in (NODE, WORKER):
    states = node_exec(node, 'systemctl', 'is-active', 'kubelet.service', 'containerd.service', success=False).stdout.split()
    assert states == ['active', 'active'], 'kubelet and containerd must stay active on ' + node
operator_account = account('opsadmin')
assert operator_account is not None, 'The opsadmin account must stay'
assert operator_account[2] != '0', 'opsadmin must not have UID 0'
assert operator_account[6] == '/bin/bash', 'opsadmin must keep the shell /bin/bash'
assert password_status('opsadmin') == 'P', 'opsadmin must keep a usable password'

old_account = account('olduser')
if wants('olduser-no-login-shell') or wants('olduser-password-locked'):
    assert old_account is not None, 'Keep the olduser account: lock it, do not delete it'

if wants('olduser-no-login-shell'):
    assert old_account[6] in REFUSING_SHELLS, 'olduser still has the login shell ' + old_account[6]
    # su starts the account's shell, so a refusing shell must make it fail.
    login = node_exec(NODE, 'su', 'olduser', '-c', 'true', success=False)
    assert login.returncode != 0, 'su olduser still starts a working shell'

if wants('olduser-password-locked'):
    status = password_status('olduser')
    assert status == 'L', 'The password of olduser has status ' + status + ', not L (locked)'

if wants('single-uid-zero'):
    uid_zero = [fields[0] for fields in account_entries() if fields[2] == '0']
    assert uid_zero == ['root'], 'Accounts with UID 0: ' + ', '.join(uid_zero) + '. Only root may have UID 0'
