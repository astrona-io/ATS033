DEFAULT_ACCOUNT = '--as=system:serviceaccount:' + NAMESPACE + ':default'


def can_i(*args):
    """The exact answer line of kubectl auth can-i: 'yes' or 'no'."""
    result = command(['kubectl', 'auth', 'can-i', *args], success=False)
    answer = result.stdout.strip()
    assert (answer, result.returncode) in (('yes', 0), ('no', 1)), 'kubectl auth can-i gave no clear answer'
    return answer


def bindings_naming(account):
    """Names of RoleBindings and ClusterRoleBindings with this ServiceAccount as a subject."""
    bindings = json.loads(kubectl('-n', NAMESPACE, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    return [binding['metadata']['name'] for binding in bindings
            if any(subject.get('kind') == 'ServiceAccount' and subject.get('name') == account
                   and subject.get('namespace') == NAMESPACE for subject in binding.get('subjects') or [])]


# The legacy-monitor ServiceAccount stays; only its long-lived token goes.
get('serviceaccount', 'legacy-monitor')

if wants('default-account-closed'):
    default = get('serviceaccount', 'default')
    assert default.get('automountServiceAccountToken') is False, 'Set automountServiceAccountToken: false on the default ServiceAccount'
    assert bindings_naming('default') == [], 'The default ServiceAccount must have no RoleBinding or ClusterRoleBinding'
    assert can_i('list', 'pods', DEFAULT_ACCOUNT, '-n', NAMESPACE) == 'no', 'The default ServiceAccount must not list Pods'
    assert can_i('create', 'deployments.apps', DEFAULT_ACCOUNT, '-n', NAMESPACE) == 'no', 'The default ServiceAccount must not create Deployments'
if wants('legacy-token-deleted'):
    result = command(['kubectl', '-n', NAMESPACE, 'get', 'secret', 'legacy-monitor-token'], success=False)
    assert result.returncode != 0, 'Delete the long-lived token Secret legacy-monitor-token'
    secrets = json.loads(kubectl('-n', NAMESPACE, 'get', 'secrets', '-o', 'json'))['items']
    remaining = [secret['metadata']['name'] for secret in secrets if secret.get('type') == 'kubernetes.io/service-account-token']
    assert remaining == [], 'No Secret of type kubernetes.io/service-account-token may remain'
