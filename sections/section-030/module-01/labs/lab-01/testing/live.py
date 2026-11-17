PORT = '19090'


def node_address(node):
    return next(item['address'] for item in get('node', node, namespace=None)['status']['addresses'] if item['type'] == 'InternalIP')


def listener_addresses(node, port):
    """Local addresses of the TCP listeners on one port, read with ss on the node."""
    output = node_exec(node, 'ss', '-tlnH', 'sport = :' + port).stdout
    return [line.split()[3].rsplit(':', 1)[0] for line in output.splitlines() if line.strip()]


# Guard for every outcome: the server still runs on the control-plane host network and answers on loopback.
assert get('pod', 'node-local-server')['spec'].get('nodeName') == NODE, 'node-local-server must run on the control-plane node'
loopback = node_exec(NODE, 'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '-m', '3', 'http://127.0.0.1:' + PORT + '/', success=False)
assert loopback.stdout.strip() == '200', 'A request to http://127.0.0.1:19090/ on the control-plane node must return 200'

if wants('loopback-listener'):
    addresses = listener_addresses(NODE, PORT)
    assert '127.0.0.1' in addresses, 'The control-plane node must have a listener on 127.0.0.1:19090'
    assert all(address in ('127.0.0.1', '[::1]') for address in addresses), 'Port 19090 must not listen on a wildcard or node address: ' + ', '.join(addresses)
if wants('node-address-refused'):
    behavior_check({'args': ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + node_address(NODE) + ':' + PORT + '/'], 'denied': True, 'failure_markers': ['connection refused']})
