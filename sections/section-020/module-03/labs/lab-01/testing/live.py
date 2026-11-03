def no_bindings_for(namespace, account):
    bindings = json.loads(kubectl('-n', namespace, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    for binding in bindings:
        for subject in binding.get('subjects', []):
            assert not (subject.get('kind') == 'ServiceAccount' and subject.get('name') == account and subject.get('namespace') == namespace), 'The ' + account + ' ServiceAccount must have no binding'

result = command(['kubectl', '-n', 'starfleet', 'get', 'secret', 'legacy-monitor-token'], success=False)
assert result.returncode != 0, 'The long-lived token Secret must be deleted'
default = get('serviceaccount', 'default', 'starfleet')
assert default.get('automountServiceAccountToken') is False, 'The default ServiceAccount must not mount a token'
no_bindings_for('starfleet', 'default')
pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=monitor', '-o', 'json'))['items']
pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
assert len(pods) == 1, 'Exactly one monitor pod must remain after the rollout'
for pod in pods:
    assert pod['spec'].get('serviceAccountName') == 'monitor', 'The monitor pod must use the monitor ServiceAccount'
    result = command(['kubectl', '-n', 'starfleet', 'exec', pod['metadata']['name'], '--', 'sh', '-c', 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo mounted || echo absent'])
    assert result.stdout.strip() == 'absent', 'The monitor pod must not receive a token'
