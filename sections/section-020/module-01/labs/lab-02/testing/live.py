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
