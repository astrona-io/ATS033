OUTPOST = 'outpost-033-030-02-02'


def node_address(node):
    return next(item['address'] for item in get('node', node, namespace=None)['status']['addresses'] if item['type'] == 'InternalIP')


def request(address):
    return ['kubectl', '-n', OUTPOST, 'exec', 'drifter', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + address + ':30081/']


# Guards: the test client and every probe endpoint run on the worker node, as the bootstrap placed them.
assert get('pod', 'drifter', namespace=OUTPOST)['spec'].get('nodeName') == WORKER, 'drifter must run on the worker node'
probe_pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
assert probe_pods and all(pod['spec'].get('nodeName') == WORKER for pod in probe_pods), 'Every probe pod must run on the worker node'

if wants('local-traffic-policy'):
    public = get('service', 'probe-public')
    assert public['spec'].get('type') == 'NodePort', 'probe-public must stay a NodePort Service'
    assert [port.get('nodePort') for port in public['spec']['ports']] == [30081], 'probe-public must keep node port 30081'
    assert public['spec'].get('externalTrafficPolicy') == 'Local', 'probe-public must use externalTrafficPolicy Local'
    behavior_check({'args': request(node_address(WORKER)), 'contains': ['version=v1']})
    behavior_check({'args': request(node_address(NODE)), 'denied': True, 'failure_markers': ['timed out']})
