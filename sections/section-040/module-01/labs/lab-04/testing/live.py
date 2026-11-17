PROFILE_FILE = '/var/lib/kubelet/seccomp/profiles/shuttle-guard.json'


def effective_seccomp(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('seccompProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('seccompProfile') or {}


pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=shuttle', '-o', 'json'))['items']
live = [item for item in pods if 'deletionTimestamp' not in item['metadata'] and item['status'].get('phase') == 'Running']
assert len(live) == 1 and len(pods) == 1, 'Exactly one shuttle pod must exist, and it must be running'
pod = live[0]
pod_name = pod['metadata']['name']
profile = effective_seccomp(pod, 'shuttle')
assert profile.get('type') == 'Localhost', 'Keep a Localhost seccomp profile for shuttle'
# The profile in use must be the approved one, whatever name it was copied to.
same_file = node_exec(NODE, 'cmp', PROFILE_FILE, '/var/lib/kubelet/seccomp/' + profile.get('localhostProfile', ''), success=False)
assert same_file.returncode == 0, 'shuttle must use the approved profile shuttle-guard.json'
if wants('shuttle-running-filtered'):
    status = kubectl('-n', NAMESPACE, 'exec', pod_name, '--', 'cat', '/proc/1/status')
    fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
    assert fields['Seccomp'].strip() == '2', 'The shuttle process has no seccomp filter'
if wants('shuttle-chmod-blocked'):
    result = command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '--', 'sh', '-c', 'touch /tmp/mode-check && chmod 600 /tmp/mode-check'], success=False)
    assert result.returncode == 1 and 'operation not permitted' in (result.stdout + result.stderr).lower(), 'chmod must still fail with Operation not permitted'
