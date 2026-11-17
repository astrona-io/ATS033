def effective_seccomp(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('seccompProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('seccompProfile') or {}


def ready(pod):
    conditions = pod['status'].get('conditions') or []
    return any(item['type'] == 'Ready' and item['status'] == 'True' for item in conditions)


pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=shuttle', '-o', 'json'))['items']
assert len(pods) == 1 and 'deletionTimestamp' not in pods[0]['metadata'], 'Exactly one shuttle pod must exist'
pod = pods[0]
pod_name = pod['metadata']['name']
assert ready(pod), 'The shuttle pod is not ready'
profile = effective_seccomp(pod, 'shuttle')
assert profile.get('type') == 'Localhost', 'Keep a Localhost seccomp profile for shuttle'
content = node_exec(NODE, 'cat', '/var/lib/kubelet/seccomp/' + profile.get('localhostProfile', ''), success=False)
assert content.returncode == 0, 'The profile file of shuttle is missing on the node'
status = kubectl('-n', NAMESPACE, 'exec', pod_name, '--', 'cat', '/proc/1/status')
fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
assert fields['Seccomp'].strip() == '2', 'The shuttle process has no seccomp filter'


def run_in_shuttle(script):
    return command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '--', 'sh', '-c', script], success=False)


if wants('shuttle-renames-work'):
    document = json.loads(content.stdout)
    assert document.get('defaultAction') == 'SCMP_ACT_ALLOW', 'Keep SCMP_ACT_ALLOW as the default action'
    moved = run_in_shuttle('echo moved > /tmp/rename-check.new && mv /tmp/rename-check.new /tmp/rename-check && cat /tmp/rename-check')
    assert moved.returncode == 0 and moved.stdout.strip() == 'moved', 'Renaming a file inside shuttle still fails'
if wants('shuttle-chown-blocked'):
    changed = run_in_shuttle('echo owner > /tmp/owner-check && chown 1000 /tmp/owner-check')
    assert changed.returncode == 1 and 'operation not permitted' in (changed.stdout + changed.stderr).lower(), 'chown must still fail with Operation not permitted'
