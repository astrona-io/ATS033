OUTPOST = 'outpost-033-020-02-01'
REVIEWER = '--as=system:serviceaccount:' + NAMESPACE + ':code-reviewer'
INSPECTOR = '--as=system:serviceaccount:' + OUTPOST + ':inspector'


def can_i(*args):
    """The exact answer line of kubectl auth can-i: 'yes' or 'no'."""
    result = command(['kubectl', 'auth', 'can-i', *args], success=False)
    answer = result.stdout.strip()
    assert (answer, result.returncode) in (('yes', 0), ('no', 1)), 'kubectl auth can-i gave no clear answer'
    return answer


def names_account(binding, namespace, account):
    return any(subject.get('kind') == 'ServiceAccount' and subject.get('name') == account and subject.get('namespace') == namespace
               for subject in binding.get('subjects') or [])


cluster_bindings = json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']

if wants('single-configmap-reader'):
    assert can_i('get', 'configmap/probe-code', REVIEWER, '-n', NAMESPACE) == 'yes', 'code-reviewer must get the ConfigMap probe-code'
    assert can_i('get', 'configmap/bridge-settings', REVIEWER, '-n', NAMESPACE) == 'no', 'code-reviewer must not get any other ConfigMap'
    for verb in ('list', 'watch', 'update', 'delete'):
        assert can_i(verb, 'configmaps', REVIEWER, '-n', NAMESPACE) == 'no', 'code-reviewer must not ' + verb + ' ConfigMaps'
    assert can_i('get', 'secrets', REVIEWER, '-n', NAMESPACE) == 'no', 'code-reviewer must not get Secrets'
    assert not any(names_account(binding, NAMESPACE, 'code-reviewer') for binding in cluster_bindings), 'Do not use a ClusterRoleBinding for code-reviewer'
if wants('namespaced-view-binding'):
    assert not any(names_account(binding, OUTPOST, 'inspector') for binding in cluster_bindings), 'Remove every ClusterRoleBinding for inspector'
    binding = get('rolebinding', 'inspector-view')
    assert binding['roleRef'] == {'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'ClusterRole', 'name': 'view'}, 'The RoleBinding inspector-view must reference the ClusterRole view'
    assert names_account(binding, OUTPOST, 'inspector'), 'The RoleBinding inspector-view must name the ServiceAccount inspector of ' + OUTPOST
    assert can_i('list', 'pods', INSPECTOR, '-n', NAMESPACE) == 'yes', 'inspector must list Pods in ' + NAMESPACE
    assert can_i('get', 'configmaps', INSPECTOR, '-n', NAMESPACE) == 'yes', 'inspector must read ConfigMaps in ' + NAMESPACE
    assert can_i('list', 'pods', INSPECTOR, '-n', OUTPOST) == 'no', 'inspector must not list Pods in ' + OUTPOST
    assert can_i('list', 'pods', INSPECTOR, '-n', 'kube-system') == 'no', 'inspector must not list Pods in kube-system'
    assert can_i('create', 'deployments.apps', INSPECTOR, '-n', NAMESPACE) == 'no', 'inspector must only read'
