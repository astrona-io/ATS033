pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=relay', '-o', 'json'))['items']
live = [p['metadata']['name'] for p in pods if 'deletionTimestamp' not in p['metadata'] and p['status'].get('phase') == 'Running']
assert len(live) == 1, 'Exactly one running relay pod is required'
pod_name = live[0]
status = kubectl('-n', NAMESPACE, 'exec', pod_name, '--', 'cat', '/proc/1/status')
fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
if wants('relay-non-root'):
    assert kubectl('-n', NAMESPACE, 'exec', pod_name, '--', 'id', '-u') == '1000', 'The process must run as user 1000'
if wants('relay-seccomp'):
    assert fields['Seccomp'].strip() == '2', 'Install the RuntimeDefault seccomp filter'
if wants('relay-no-escalation'):
    assert fields['NoNewPrivs'].strip() == '1', 'Block privilege escalation'
if wants('relay-capabilities'):
    assert fields['CapBnd'].strip() == '0000000000000400', 'Keep only NET_BIND_SERVICE'
