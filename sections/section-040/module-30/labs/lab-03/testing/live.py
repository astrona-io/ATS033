ONLY_NET_BIND_SERVICE = '0000000000000400'

pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=relay', '-o', 'json'))['items']
assert len(pods) == 1 and 'deletionTimestamp' not in pods[0]['metadata'], 'Exactly one relay pod must exist'
pod = pods[0]
pod_name = pod['metadata']['name']
conditions = pod['status'].get('conditions') or []
assert any(item['type'] == 'Ready' and item['status'] == 'True' for item in conditions), 'The relay pod is not ready'
container = next((item for item in pod['spec']['containers'] if item['name'] == 'relay'), None)
assert container is not None, 'Keep the container named relay'
container_context = container.get('securityContext') or {}
status = kubectl('-n', NAMESPACE, 'exec', pod_name, '--', 'cat', '/proc/1/status')
fields = {key: value.strip() for key, value in (line.split(':', 1) for line in status.splitlines() if ':' in line)}


def run_in_relay(script):
    return command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '--', 'sh', '-c', script], success=False)


if wants('relay-no-escalation'):
    assert container_context.get('privileged') is not True, 'The relay container must not be privileged'
    assert fields['NoNewPrivs'] == '1', 'Privilege escalation is still allowed (NoNewPrivs is not 1)'
if wants('relay-capability-set'):
    assert fields['CapBnd'] == ONLY_NET_BIND_SERVICE, 'CapBnd must hold only NET_BIND_SERVICE, found ' + fields['CapBnd']
    assert fields['CapEff'] == ONLY_NET_BIND_SERVICE, 'CapEff must hold only NET_BIND_SERVICE, found ' + fields['CapEff']
if wants('relay-still-serves'):
    page = run_in_relay('wget -qO- http://127.0.0.1:80/')
    assert page.returncode == 0 and page.stdout.strip() == 'relay-ok', 'relay no longer serves its page on port 80'
    changed = run_in_relay('chown 1000 /www/index.html')
    assert changed.returncode == 1 and 'operation not permitted' in (changed.stdout + changed.stderr).lower(), 'chown must fail with Operation not permitted'
