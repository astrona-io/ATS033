if wants('node-local-server'):
    assert get('pod', 'node-local-server')['spec'].get('nodeName') == NODE, 'Run node-local-server on the control-plane node'
if wants('loopback-only'):
    address = next(address['address'] for address in get('node', NODE, namespace=None)['status']['addresses'] if address['type'] == 'InternalIP')
    behavior_check({'args': ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + address + ':19090/'], 'denied': True, 'failure_markers': ['connection refused']})
