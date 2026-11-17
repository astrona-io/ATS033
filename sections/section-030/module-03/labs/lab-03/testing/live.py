KUBELET_PODS_URL = 'https://127.0.0.1:10250/pods'


def kubelet_status(*headers):
    """HTTP status code of a request from inside the worker node to its kubelet."""
    args = ['curl', '-sk', '-o', '/dev/null', '-w', '%{http_code}', '-m', '5']
    for header in headers:
        args += ['-H', header]
    return node_exec(WORKER, *args, KUBELET_PODS_URL, success=False).stdout.strip()


# Guards: the worker stays Ready, and the running kubelet still authenticates bearer tokens.
assert kubectl('get', 'node', WORKER, '-o', 'jsonpath={.status.conditions[?(@.type=="Ready")].status}') == 'True', 'The worker node must stay Ready'
running = json.loads(kubectl('get', '--raw', '/api/v1/nodes/' + WORKER + '/proxy/configz'))['kubeletconfig']
assert running['authentication']['webhook']['enabled'] is True, 'The kubelet must keep webhook authentication enabled'

if wants('anonymous-auth-disabled'):
    assert running['authentication']['anonymous']['enabled'] is False, 'The running kubelet must have anonymous authentication disabled'
    assert kubelet_status() == '401', 'An anonymous request to the kubelet must get 401'

if wants('webhook-authorization'):
    assert running['authorization']['mode'] == 'Webhook', 'The running kubelet must use the Webhook authorization mode'
    token = kubectl('-n', NAMESPACE, 'create', 'token', 'metrics-reader', '--duration=10m')
    assert kubelet_status('Authorization: Bearer ' + token) == '403', 'A token without nodes/proxy permission must get 403 from the kubelet'
