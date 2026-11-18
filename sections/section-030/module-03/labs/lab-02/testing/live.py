API_SERVER = 'https://127.0.0.1:6443'
SHUTTLE_ACCOUNT = 'system:serviceaccount:' + NAMESPACE + ':shuttle'


def anonymous_status(path):
    """HTTP status code of a request without credentials, sent from the control-plane node."""
    args = ['curl', '-sk', '-o', '/dev/null', '-w', '%{http_code}', '-m', '5', API_SERVER + path]
    return node_exec(NODE, *args, success=False).stdout.strip()


ANONYMOUS_SUBJECTS = {('User', 'system:anonymous'), ('Group', 'system:unauthenticated')}


def anonymous_bindings(kind, *scope):
    """Names of bindings of this kind that list system:anonymous or system:unauthenticated as a subject."""
    items = json.loads(command(['kubectl', 'get', kind, *scope, '-o', 'json']).stdout)['items']
    found = []
    for item in items:
        if item['metadata']['name'] == 'system:public-info-viewer':
            continue
        for subject in item.get('subjects') or []:
            if (subject.get('kind'), subject.get('name')) in ANONYMOUS_SUBJECTS:
                found.append(item['metadata']['name'])
    return found


def can_i(*args):
    """Answer of kubectl auth can-i: 'yes' or 'no'."""
    return command(['kubectl', 'auth', 'can-i', *args], success=False).stdout.strip()


# Guards: the API server keeps anonymous health checks, and the named callers keep their access.
assert anonymous_status('/healthz') == '200', 'Anonymous health checks on /healthz must keep working'
assert can_i('list', 'namespaces', '--as=ops-user', '--as-group=ops-team') == 'yes', 'The group ops-team must still list namespaces'
assert can_i('list', 'pods', '-n', NAMESPACE, '--as=' + SHUTTLE_ACCOUNT) == 'yes', 'The ServiceAccount shuttle must still list pods'

if wants('anonymous-namespace-list-denied'):
    assert anonymous_status('/api/v1/namespaces') in ('401', '403'), 'An anonymous request must not list namespaces'
    assert not anonymous_bindings('clusterrolebindings'), 'No ClusterRoleBinding may name system:anonymous or system:unauthenticated'

if wants('unauthenticated-pod-read-denied'):
    assert anonymous_status('/api/v1/namespaces/' + NAMESPACE + '/pods') in ('401', '403'), 'An anonymous request must not list pods'
    assert not anonymous_bindings('rolebindings', '-n', NAMESPACE), 'No RoleBinding in the namespace may name system:anonymous or system:unauthenticated'
