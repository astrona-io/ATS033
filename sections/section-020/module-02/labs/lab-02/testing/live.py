OUTPOST = 'outpost-033-020-02-02'
AGENT = '--as=system:serviceaccount:' + NAMESPACE + ':ops-agent'
READER_RULES = {('', 'pods', 'get'), ('', 'pods', 'list'), ('', 'pods/log', 'get')}


def can_i(*args):
    """The exact answer line of kubectl auth can-i: 'yes' or 'no'."""
    result = command(['kubectl', 'auth', 'can-i', *args], success=False)
    answer = result.stdout.strip()
    assert (answer, result.returncode) in (('yes', 0), ('no', 1)), 'kubectl auth can-i gave no clear answer'
    return answer


def bound_roles(namespace, account):
    """(binding kind, binding name, roleRef) for every binding of the ServiceAccount."""
    found = []
    bindings = json.loads(kubectl('-n', namespace, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    for binding in bindings:
        if any(s.get('kind') == 'ServiceAccount' and s.get('name') == account and s.get('namespace') == namespace for s in binding.get('subjects') or []):
            found.append((binding['kind'], binding['metadata']['name'], binding['roleRef']))
    return found


def rules_of(namespace, reference):
    if reference['kind'] == 'ClusterRole':
        return get('clusterrole', reference['name'], None).get('rules') or []
    return get('role', reference['name'], namespace).get('rules') or []


def flatten(rules):
    """Every (apiGroup, resource, verb) a rule list grants; resourceNames are not allowed here."""
    granted = set()
    for rule in rules:
        assert not rule.get('resourceNames') and not rule.get('nonResourceURLs'), 'ops-agent-reader must not use resourceNames or nonResourceURLs'
        for group in rule.get('apiGroups') or []:
            for resource in rule.get('resources') or []:
                for verb in rule.get('verbs') or []:
                    granted.add((group, resource, verb))
    return granted


bindings = bound_roles(NAMESPACE, 'ops-agent')
if wants('cluster-admin-removed'):
    result = command(['kubectl', 'get', 'clusterrolebinding', 'ops-agent-admin'], success=False)
    assert result.returncode != 0, 'Remove the ClusterRoleBinding ops-agent-admin'
    assert all(kind != 'ClusterRoleBinding' for kind, _, _ in bindings), 'ops-agent must have no ClusterRoleBinding'
    assert all(reference['name'] != 'cluster-admin' for _, _, reference in bindings), 'Remove every binding to cluster-admin'
    assert can_i('list', 'nodes', AGENT) == 'no', 'ops-agent must not list nodes'
    assert can_i('list', 'pods', AGENT, '-n', OUTPOST) == 'no', 'ops-agent must not list Pods in ' + OUTPOST
if wants('wildcard-binding-removed'):
    for kind in ('rolebinding', 'role'):
        result = command(['kubectl', '-n', NAMESPACE, 'get', kind, 'ops-wide'], success=False)
        assert result.returncode != 0, 'Delete the ' + kind + ' ops-wide'
    for _, _, reference in bindings:
        if reference['name'] == 'cluster-admin':
            continue
        for rule in rules_of(NAMESPACE, reference):
            for field in ('apiGroups', 'resources', 'verbs'):
                assert '*' not in (rule.get(field) or []), 'Do not bind a Role with a wildcard in ' + field
if wants('least-privilege-reader'):
    assert bindings == [('RoleBinding', 'ops-agent-reader', {'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'Role', 'name': 'ops-agent-reader'})], \
        'ops-agent must have exactly one binding: the RoleBinding ops-agent-reader to the Role ops-agent-reader'
    assert flatten(rules_of(NAMESPACE, bindings[0][2])) == READER_RULES, 'The Role ops-agent-reader must grant exactly get and list on pods and get on pods/log'
    for verb, resource in (('get', 'pods'), ('list', 'pods'), ('get', 'pods/log')):
        assert can_i(verb, resource, AGENT, '-n', NAMESPACE) == 'yes', 'ops-agent must ' + verb + ' ' + resource
    for verb, resource in (('delete', 'pods'), ('create', 'pods/exec'), ('get', 'secrets'), ('create', 'deployments.apps')):
        assert can_i(verb, resource, AGENT, '-n', NAMESPACE) == 'no', 'ops-agent must not ' + verb + ' ' + resource
