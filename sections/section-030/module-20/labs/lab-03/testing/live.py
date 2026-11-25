LEGACY_ADDRESS = '203.0.113.10'
DENIED_MARKERS = ['timed out', 'connection refused', 'unreachable']


def node_address(node):
    return next(item['address'] for item in get('node', node, namespace=None)['status']['addresses'] if item['type'] == 'InternalIP')


def request(url):
    return ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', url]


def cluster_items(kind):
    return json.loads(kubectl('get', kind, '-A', '-o', 'json'))['items']


def full_name(item):
    return item['metadata']['namespace'] + '/' + item['metadata']['name']


if wants('no-external-ips'):
    with_external_ips = [full_name(service) for service in cluster_items('services') if service['spec'].get('externalIPs')]
    assert not with_external_ips, 'These Services still set externalIPs: ' + ', '.join(with_external_ips)
    behavior_check({'args': request('http://probe-legacy/'), 'contains': ['version=v1']})
    behavior_check({'args': request('http://' + LEGACY_ADDRESS + '/'), 'denied': True, 'failure_markers': DENIED_MARKERS})

if wants('single-node-port'):
    with_node_ports = sorted(full_name(service) for service in cluster_items('services') if any('nodePort' in port for port in service['spec'].get('ports', [])))
    assert with_node_ports == [NAMESPACE + '/probe-public'], 'Only probe-public may keep a node port, found: ' + ', '.join(with_node_ports)
    worker_ip = node_address(WORKER)
    behavior_check({'args': request('http://' + worker_ip + ':30081/'), 'contains': ['version=v1']})
    behavior_check({'args': request('http://' + worker_ip + ':30090/'), 'denied': True, 'failure_markers': DENIED_MARKERS})

if wants('no-host-network-listener'):
    host_network_pods = [full_name(pod) for pod in cluster_items('pods') if pod['spec'].get('hostNetwork') and not pod['metadata']['namespace'].startswith('kube-')]
    assert not host_network_pods, 'These pods outside kube-* namespaces still use the host network: ' + ', '.join(host_network_pods)
    behavior_check({'args': request('http://' + node_address(WORKER) + ':18080/'), 'denied': True, 'failure_markers': ['connection refused']})
