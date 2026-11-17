PORT = '19091'


def node_address(node):
    return next(item['address'] for item in get('node', node, namespace=None)['status']['addresses'] if item['type'] == 'InternalIP')


NODE_IP = node_address(NODE)

# Guards for every outcome: the server still listens, and the test clients run where the task says.
assert get('pod', 'node-metrics-server')['spec'].get('nodeName') == NODE, 'node-metrics-server must run on the control-plane node'
assert node_exec(NODE, 'ss', '-tlnH', 'sport = :' + PORT).stdout.strip(), 'The control-plane node must still have a listener on port 19091'
assert get('pod', 'shuttle')['spec'].get('nodeName') == NODE, 'shuttle must run on the control-plane node'
assert get('pod', 'scout')['spec'].get('nodeName') == WORKER, 'scout must run on the worker node'

if wants('worker-only-access'):
    behavior_check({'args': ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + NODE_IP + ':' + PORT + '/'], 'denied': True, 'failure_markers': ['timed out']})
    behavior_check({'args': ['kubectl', '-n', NAMESPACE, 'exec', 'scout', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + NODE_IP + ':' + PORT + '/'], 'contains': ['Directory listing for /']})
