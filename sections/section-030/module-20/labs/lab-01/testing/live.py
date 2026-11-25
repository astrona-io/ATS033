OUTPOST = 'outpost-033-030-02-01'


def node_address(node):
    return next(item['address'] for item in get('node', node, namespace=None)['status']['addresses'] if item['type'] == 'InternalIP')


if wants('debug-cluster-ip'):
    debug = get('service', 'probe-debug')
    assert debug['spec'].get('type') == 'ClusterIP', 'probe-debug must be a ClusterIP Service'
    assert all('nodePort' not in port for port in debug['spec']['ports']), 'probe-debug must not keep a node port'
    behavior_check({'args': ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://probe-debug/'], 'contains': ['version=v1']})

if wants('node-port-closed'):
    for node in (NODE, WORKER):
        behavior_check({'args': ['kubectl', '-n', OUTPOST, 'exec', 'drifter', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + node_address(node) + ':30080/'], 'denied': True, 'failure_markers': ['connection refused', 'timed out']})
