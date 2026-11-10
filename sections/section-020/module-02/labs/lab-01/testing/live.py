def bound_roles(namespace, account):
    """(binding kind, binding name, roleRef) for every binding of the ServiceAccount."""
    found = []
    bindings = json.loads(kubectl('-n', namespace, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    for binding in bindings:
        if any(s.get('kind') == 'ServiceAccount' and s.get('name') == account and s.get('namespace') == namespace for s in binding.get('subjects', [])):
            found.append((binding['kind'], binding['metadata']['name'], binding['roleRef']))
    return found

def rules_of(namespace, reference):
    if reference['kind'] == 'ClusterRole':
        return json.loads(kubectl('get', 'clusterrole', reference['name'], '-o', 'json')).get('rules', [])
    return json.loads(kubectl('-n', namespace, 'get', 'role', reference['name'], '-o', 'json')).get('rules', [])

bindings = bound_roles(NAMESPACE, 'ops-agent')
if wants('cluster-admin-removed'):
    result = command(['kubectl', 'get', 'clusterrolebinding', 'ops-agent-admin'], success=False)
    assert result.returncode != 0, 'Remove the ClusterRoleBinding ops-agent-admin'
    assert all(reference['name'] != 'cluster-admin' for _, _, reference in bindings), 'Remove every binding to cluster-admin'
if wants('wildcard-binding-removed'):
    result = command(['kubectl', '-n', NAMESPACE, 'get', 'rolebinding', 'ops-wide'], success=False)
    assert result.returncode != 0, 'Remove the wildcard RoleBinding ops-wide'
    for _, _, reference in bindings:
        for rule in rules_of(NAMESPACE, reference):
            for field in ('apiGroups', 'resources', 'verbs'):
                assert '*' not in rule.get(field, []), 'Do not bind a Role with a wildcard in ' + field
if wants('least-privilege-reader'):
    assert ('RoleBinding', 'ops-agent-reader', {'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'Role', 'name': 'ops-agent-reader'}) in bindings, 'Bind ops-agent to the Role ops-agent-reader with the RoleBinding ops-agent-reader'
