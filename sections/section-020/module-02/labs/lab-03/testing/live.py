DASHBOARD = '--as=system:serviceaccount:' + NAMESPACE + ':dashboard'
DEFAULT_ACCOUNT = '--as=system:serviceaccount:' + NAMESPACE + ':default'
BROAD_GROUPS = {'system:serviceaccounts', 'system:serviceaccounts:' + NAMESPACE, 'system:authenticated'}


def can_i(*args):
    """The exact answer line of kubectl auth can-i: 'yes' or 'no'."""
    result = command(['kubectl', 'auth', 'can-i', *args], success=False)
    answer = result.stdout.strip()
    assert (answer, result.returncode) in (('yes', 0), ('no', 1)), 'kubectl auth can-i gave no clear answer'
    return answer


def grants_secrets(rules):
    return any('secrets' in (rule.get('resources') or []) or '*' in (rule.get('resources') or []) for rule in rules or [])


# Guards for every outcome: the legitimate read access stays.
assert can_i('list', 'pods', DASHBOARD, '-n', NAMESPACE) == 'yes', 'dashboard must keep its view access'
assert can_i('list', 'configmaps', '--as=auditor', '-n', NAMESPACE) == 'yes', 'auditor must keep its view access'
assert get('clusterrole', 'view', None).get('aggregationRule'), 'Keep the aggregationRule of the ClusterRole view'

if wants('aggregated-secret-access-removed'):
    assert not grants_secrets(get('clusterrole', 'view', None).get('rules')), 'The ClusterRole view must not grant Secrets'
    roles = json.loads(kubectl('get', 'clusterroles', '-l', 'rbac.authorization.k8s.io/aggregate-to-view=true', '-o', 'json'))['items']
    assert not any(grants_secrets(role.get('rules')) for role in roles), 'No ClusterRole that aggregates into view may grant Secrets'
    assert can_i('get', 'secrets', '--as=auditor', '-n', NAMESPACE) == 'no', 'auditor must not get Secrets'
    assert can_i('list', 'secrets', '--as=auditor', '-n', NAMESPACE) == 'no', 'auditor must not list Secrets'
if wants('group-binding-removed'):
    bindings = json.loads(kubectl('-n', NAMESPACE, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    for binding in bindings:
        if binding['roleRef']['name'] in ('edit', 'admin', 'cluster-admin'):
            for subject in binding.get('subjects') or []:
                assert not (subject.get('kind') == 'Group' and subject.get('name') in BROAD_GROUPS), \
                    'Remove the binding ' + binding['metadata']['name'] + ' that gives ' + binding['roleRef']['name'] + ' to ' + subject['name']
    assert can_i('list', 'pods', DEFAULT_ACCOUNT, '-n', NAMESPACE) == 'no', 'The default ServiceAccount must have no access'
    assert can_i('create', 'deployments.apps', DASHBOARD, '-n', NAMESPACE) == 'no', 'dashboard must not create Deployments'
    assert can_i('delete', 'pods', DASHBOARD, '-n', NAMESPACE) == 'no', 'dashboard must not delete Pods'
