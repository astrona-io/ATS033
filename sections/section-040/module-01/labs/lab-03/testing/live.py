def ready(pod):
    conditions = pod['status'].get('conditions') or []
    return any(item['type'] == 'Ready' and item['status'] == 'True' for item in conditions)


pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=scout', '-o', 'json'))['items']
assert len(pods) == 1 and 'deletionTimestamp' not in pods[0]['metadata'], 'Exactly one scout pod must exist'
pod = pods[0]
assert pod['status'].get('phase') == 'Running' and ready(pod), 'The scout pod must be running and ready'
pod_name = pod['metadata']['name']


def run_in_scout(script):
    return command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '-c', 'scout', '--', 'sh', '-c', script], success=False)


if wants('scout-non-root'):
    user_id = run_in_scout('id -u')
    assert user_id.returncode == 0 and user_id.stdout.strip() not in ('', '0'), 'The scout process still runs as user ID 0'
    container = next(item for item in pod['spec']['containers'] if item['name'] == 'scout')
    own = (container.get('securityContext') or {}).get('runAsNonRoot')
    shared = (pod['spec'].get('securityContext') or {}).get('runAsNonRoot')
    assert (own if own is not None else shared) is True, 'Set runAsNonRoot: true so the kubelet refuses a root user'
if wants('scout-read-only-root'):
    root_write = run_in_scout('touch /scout-root-check')
    assert root_write.returncode != 0 and 'read-only file system' in (root_write.stdout + root_write.stderr).lower(), 'Writing to / must fail with Read-only file system'
    scratch = run_in_scout('echo scratch > /tmp/scout-scratch-check && cat /tmp/scout-scratch-check')
    assert scratch.returncode == 0 and scratch.stdout.strip() == 'scratch', 'Writing under /tmp must still work'
if wants('scout-restricted-admission'):
    dry_run = command(['kubectl', 'label', '--dry-run=server', '--overwrite', 'namespace', NAMESPACE, 'pod-security.kubernetes.io/enforce=restricted'], success=False)
    output = dry_run.stdout + dry_run.stderr
    assert dry_run.returncode == 0, 'The dry run failed: ' + output.strip()
    assert 'violate' not in output, 'The restricted Pod Security level still reports a violation'
