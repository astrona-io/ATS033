LOG = '/srv/flight-logs/telemetry.log'
CONTENT = 'orbit=stable fuel=82'


def on_node(*args, success=True):
    return node_exec(NODE, *args, success=success)


def read_as(account):
    return on_node('runuser', '-u', account, '--', 'cat', LOG, success=False)


def groups_of(account):
    return set(on_node('id', '-Gn', account).stdout.split())


# Guards for every outcome: both accounts exist with their own non-root UID,
# and root still owns the log file.
for account in ('navigator', 'cadet'):
    assert on_node('id', '-u', account, success=False).stdout.strip() not in ('', '0'), 'Keep the account ' + account + ' with a non-root UID'
owner, group, mode = on_node('stat', '-c', '%U %G %a', LOG).stdout.split()
assert owner == 'root', 'Keep root as the owner of ' + LOG

if wants('navigator-group-read'):
    assert groups_of('navigator') == {'navigator', 'flight-log-readers'}, 'navigator must belong to its own group and flight-log-readers only'
    assert group == 'flight-log-readers', 'The group of ' + LOG + ' must be flight-log-readers'
    result = read_as('navigator')
    assert result.returncode == 0 and result.stdout.strip() == CONTENT, 'navigator must be able to read ' + LOG
if wants('other-accounts-denied'):
    assert group == 'flight-log-readers', 'The group of ' + LOG + ' must be flight-log-readers'
    assert int(mode, 8) & 0o007 == 0, 'Other accounts must have no access to ' + LOG
    assert int(mode, 8) & 0o040, 'The group flight-log-readers must keep read access to ' + LOG
    assert groups_of('cadet') == {'cadet'}, 'cadet must not join any extra group'
    result = read_as('cadet')
    assert result.returncode != 0 and 'Permission denied' in result.stderr, 'cadet must be denied reading ' + LOG
