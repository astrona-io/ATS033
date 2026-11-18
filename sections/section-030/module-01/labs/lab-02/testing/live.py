PORT = '19091'


def node_address(node):
    return next(item['address'] for item in get('node', node, namespace=None)['status']['addresses'] if item['type'] == 'InternalIP')


NODE_IP = node_address(NODE)

# Guards for every outcome: the server still listens on every address, and
# the node itself still reaches it through its own InternalIP.
assert get('pod', 'node-metrics-server')['spec'].get('nodeName') == NODE, 'node-metrics-server must run on the node'
listeners = node_exec(NODE, 'ss', '-tlnH', 'sport = :' + PORT).stdout
assert listeners.strip(), 'The node must still have a listener on port 19091'
assert '127.0.0.1:' + PORT not in listeners, 'Keep the bind address of node-metrics-server; block the port with ufw'
local = node_exec(NODE, 'curl', '-s', '-m', '5', 'http://' + NODE_IP + ':' + PORT + '/', success=False)
assert 'Directory listing for /' in local.stdout, 'A request from the node itself to ' + NODE_IP + ':19091 must still return the page'

if wants('ufw-deny-rule'):
    status = node_exec(NODE, 'ufw', 'status').stdout
    assert 'Status: active' in status, 'ufw must be active'
    rules = [line for line in status.splitlines() if line.split() and line.split()[0] in ('19091/tcp', '19091')]
    assert any(' DENY ' in ' ' + line + ' ' or ' REJECT ' in ' ' + line + ' ' for line in rules), 'ufw must have a DENY or REJECT rule for TCP port 19091'
if wants('pod-access-blocked'):
    behavior_check({'args': ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + NODE_IP + ':' + PORT + '/'], 'denied': True, 'failure_markers': ['timed out', 'connection refused']})
