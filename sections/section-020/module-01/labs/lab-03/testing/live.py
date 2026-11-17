ROSTER = '/srv/flight-ops/roster'
ROSTER_CONTENT = 'shift=night lead=crew-member'
CREW_RULE = 'crew-member ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet'


def on_node(*args, success=True):
    return node_exec(NODE, *args, success=success)


def read_as(account):
    return on_node('runuser', '-u', account, '--', 'cat', ROSTER, success=False)


def can_i(*args):
    """The exact answer line of kubectl auth can-i: 'yes' or 'no'."""
    result = command(['kubectl', 'auth', 'can-i', *args], success=False)
    answer = result.stdout.strip()
    assert (answer, result.returncode) in (('yes', 0), ('no', 1)), 'kubectl auth can-i gave no clear answer'
    return answer


def names_leaver(binding):
    return any(subject.get('kind') == 'User' and subject.get('name') == 'leaver' for subject in binding.get('subjects') or [])


# Guards for every outcome: leaver still exists (lock, do not delete), and
# crew-member keeps its group read, its sudoers rule and its view access.
assert on_node('id', '-u', 'leaver', success=False).returncode == 0, 'Keep the account leaver; lock it instead of deleting it'
assert on_node('stat', '-c', '%U:%G:%a', ROSTER).stdout.strip() == 'root:flight-ops:640', 'Keep ' + ROSTER + ' as root:flight-ops with mode 640'
result = read_as('crew-member')
assert result.returncode == 0 and result.stdout.strip() == ROSTER_CONTENT, 'crew-member must still read ' + ROSTER
assert on_node('cat', '/etc/sudoers.d/crew-member', success=False).stdout.strip() == CREW_RULE, 'Keep the sudoers rule of crew-member'
assert can_i('list', 'pods', '--as=crew-member', '-n', NAMESPACE) == 'yes', 'crew-member must keep its view access'

if wants('group-access-revoked'):
    assert 'flight-ops' not in on_node('id', '-Gn', 'leaver').stdout.split(), 'Remove leaver from the group flight-ops'
    result = read_as('leaver')
    assert result.returncode != 0 and 'Permission denied' in result.stderr, 'leaver must be denied reading ' + ROSTER
if wants('sudo-rule-removed'):
    result = on_node('grep', '-rlw', 'leaver', '/etc/sudoers.d', success=False)
    assert result.returncode == 1 and not result.stdout.strip(), 'Remove every sudoers rule for leaver'
    result = on_node('grep', '-sw', 'leaver', '/etc/sudoers', success=False)
    assert not result.stdout.strip(), 'Remove every sudoers rule for leaver'
    if on_node('sh', '-c', 'command -v visudo', success=False).returncode == 0:
        assert on_node('visudo', '-c', success=False).returncode == 0, 'The sudoers files must pass visudo -c'
if wants('cluster-access-revoked'):
    bindings = json.loads(kubectl('get', 'rolebindings', '-A', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    assert not any(names_leaver(binding) for binding in bindings), 'Remove every RoleBinding and ClusterRoleBinding that names the user leaver'
    assert can_i('create', 'deployments.apps', '--as=leaver', '-n', NAMESPACE) == 'no', 'leaver must not create Deployments'
    assert can_i('list', 'pods', '--as=leaver', '-n', NAMESPACE) == 'no', 'leaver must not list pods'
    assert can_i('list', 'nodes', '--as=leaver') == 'no', 'leaver must not list nodes'
if wants('account-locked'):
    assert on_node('passwd', '-S', 'leaver').stdout.split()[1] == 'L', 'Lock the password of leaver (passwd -S must show L)'
