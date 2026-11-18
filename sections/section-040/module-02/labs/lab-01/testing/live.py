def effective_seccomp(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('seccompProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('seccompProfile') or {}


def check_filtered_pods(app, replicas):
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=' + app, '-o', 'json'))['items']
    assert len(pods) == replicas, 'Wait until exactly %d %s pod(s) exist' % (replicas, app)
    for pod in pods:
        pod_name = pod['metadata']['name']
        assert 'deletionTimestamp' not in pod['metadata'] and pod['status'].get('phase') == 'Running', pod_name + ' is not running'
        container = next(item for item in pod['spec']['containers'] if item['name'] == app)
        assert not (container.get('securityContext') or {}).get('privileged'), pod_name + ' still runs privileged'
        assert effective_seccomp(pod, app).get('type') == 'RuntimeDefault', pod_name + ' does not use the RuntimeDefault seccomp profile'
        status = kubectl('-n', NAMESPACE, 'exec', pod_name, '-c', app, '--', 'cat', '/proc/1/status')
        fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
        assert fields['Seccomp'].strip() == '2', pod_name + ' has no seccomp filter'


if wants('bridge-runtime-default'):
    check_filtered_pods('bridge', 2)
if wants('scout-runtime-default'):
    check_filtered_pods('scout', 1)
