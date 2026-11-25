TOKEN_DIRECTORY = '/var/run/secrets/kubernetes.io/serviceaccount'
MONITOR = '--as=system:serviceaccount:' + NAMESPACE + ':monitor'


def can_i(*args):
    """The exact answer line of kubectl auth can-i: 'yes' or 'no'."""
    result = command(['kubectl', 'auth', 'can-i', *args], success=False)
    answer = result.stdout.strip()
    assert (answer, result.returncode) in (('yes', 0), ('no', 1)), 'kubectl auth can-i gave no clear answer'
    return answer


def running_pod(app):
    """The one live Pod of a Deployment after its rollout."""
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=' + app, '-o', 'json'))['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    assert len(pods) == 1, 'Exactly one ' + app + ' Pod must remain after the rollout'
    return pods[0]


def token_listing(pod):
    """What the container sees at the default token path: the file list, or 'absent'."""
    return kubectl('-n', NAMESPACE, 'exec', pod['metadata']['name'], '--', 'sh', '-c',
                   'ls ' + TOKEN_DIRECTORY + ' 2>/dev/null || echo absent')


if wants('monitor-dedicated-account'):
    get('serviceaccount', 'monitor')
    pod = running_pod('monitor')
    assert pod['spec'].get('serviceAccountName') == 'monitor', 'The monitor Pod must use the ServiceAccount monitor'
    assert 'token' in token_listing(pod).split(), 'The monitor Pod needs its token to call the API server'
    assert can_i('list', 'pods', MONITOR, '-n', NAMESPACE) == 'yes', 'monitor must list Pods'
    assert can_i('get', 'secrets', MONITOR, '-n', NAMESPACE) == 'no', 'monitor must not read Secrets'
    assert can_i('delete', 'pods', MONITOR, '-n', NAMESPACE) == 'no', 'monitor must not delete Pods'
if wants('probe-without-token'):
    pod = running_pod('probe')
    assert token_listing(pod) == 'absent', 'The probe Pod must not mount a ServiceAccount token'
