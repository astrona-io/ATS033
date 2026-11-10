if wants('debug-node-port-closed'):
    debug = get('service', 'probe-debug')
    assert all('nodePort' not in port for port in debug['spec']['ports']), 'probe-debug must not keep a node port'
    address = next(a['address'] for a in get('node', NODE, namespace=None)['status']['addresses'] if a['type'] == 'InternalIP')
    behavior_check({'args': ['kubectl', '-n', 'outpost-033-030-02-01', 'exec', 'drifter', '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + address + ':30080/'], 'denied': True, 'failure_markers': ['connection refused', 'timed out']})
if wants('public-local-traffic'):
    public = get('service', 'probe-public')
    assert [port.get('nodePort') for port in public['spec']['ports']] == [30081], 'probe-public must keep node port 30081'
