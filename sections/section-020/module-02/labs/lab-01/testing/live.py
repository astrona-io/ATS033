def effective_rules(namespace, account):
    """Collect the rules that bind the ServiceAccount, and reject wildcards and cluster-admin."""
    found = []
    bindings = json.loads(kubectl('-n', namespace, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    for binding in bindings:
        names = [s for s in binding.get('subjects', []) if s.get('kind') == 'ServiceAccount' and s.get('name') == account and s.get('namespace') == namespace]
        if not names:
            continue
        reference = binding['roleRef']
        assert reference['name'] != 'cluster-admin', 'Remove every binding to cluster-admin'
        if reference['kind'] == 'ClusterRole':
            role = json.loads(kubectl('get', 'clusterrole', reference['name'], '-o', 'json'))
        else:
            role = json.loads(kubectl('-n', namespace, 'get', 'role', reference['name'], '-o', 'json'))
        found += role.get('rules', [])
    return found

result = command(['kubectl', 'get', 'clusterrolebinding', 'ops-agent-admin'], success=False)
assert result.returncode != 0, 'The ClusterRoleBinding to cluster-admin must be removed'
result = command(['kubectl', '-n', 'starfleet', 'get', 'rolebinding', 'ops-wide'], success=False)
assert result.returncode != 0, 'The wildcard RoleBinding must be removed'
rules = effective_rules('starfleet', 'ops-agent')
assert rules, 'The ServiceAccount needs a narrow Role'
for rule in rules:
    for field in ('apiGroups', 'resources', 'verbs'):
        assert '*' not in rule.get(field, []), 'Do not use a wildcard in ' + field
