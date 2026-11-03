def binding_subjects(namespace):
    bindings = json.loads(kubectl('-n', namespace, 'get', 'rolebindings', '-o', 'json'))['items']
    bindings += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    return bindings

def assert_no_binding(namespace, account):
    for binding in binding_subjects(namespace):
        for subject in binding.get('subjects', []):
            assert not (subject.get('kind') == 'ServiceAccount' and subject.get('name') == account and subject.get('namespace') == namespace and binding['roleRef']['name'] in ('cluster-admin', 'edit', 'admin')), 'Remove the broad binding of ' + account

result = command(['kubectl', 'get', 'clusterrolebinding', 'deployer-admin'], success=False)
assert result.returncode != 0, 'The ClusterRoleBinding to cluster-admin must be removed'
result = command(['kubectl', '-n', 'outpost', 'get', 'secret', 'legacy-deployer-token'], success=False)
assert result.returncode != 0, 'The long-lived token Secret must be deleted'
assert_no_binding('outpost', 'deployer')
assert_no_binding('outpost', 'default')
default = get('serviceaccount', 'default', 'outpost')
assert default.get('automountServiceAccountToken') is False, 'The default ServiceAccount in outpost must not mount a token'
for binding in binding_subjects('outpost'):
    for subject in binding.get('subjects', []):
        assert not (subject.get('kind') == 'ServiceAccount' and subject.get('name') == 'default' and subject.get('namespace') == 'outpost'), 'The default ServiceAccount must have no binding'
deployment = get('deployment', 'reporter', 'outpost')
template = deployment['spec']['template']['spec']
assert template.get('serviceAccountName') == 'reporter', 'The reporter Deployment must use the reporter ServiceAccount'
assert template.get('automountServiceAccountToken') is False, 'Turn off the automatic token mount on the pod'
projected = [source['serviceAccountToken'] for volume in template.get('volumes', []) for source in volume.get('projected', {}).get('sources', []) if 'serviceAccountToken' in source]
assert len(projected) == 1 and projected[0].get('expirationSeconds') == 3600 and projected[0].get('path') == 'api-token', 'Project one token that expires after 3600 seconds'
pods = json.loads(kubectl('-n', 'outpost', 'get', 'pods', '-l', 'app=reporter', '-o', 'json'))['items']
pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
assert len(pods) == 1, 'Exactly one reporter pod must remain after the rollout'
name = pods[0]['metadata']['name']
result = command(['kubectl', '-n', 'outpost', 'exec', name, '--', 'sh', '-c', 'test -s /var/run/secrets/tokens/api-token && echo present || echo absent'])
assert result.stdout.strip() == 'present', 'The projected token file must exist in the pod'
result = command(['kubectl', '-n', 'outpost', 'exec', name, '--', 'sh', '-c', 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo mounted || echo absent'])
assert result.stdout.strip() == 'absent', 'The default token mount must be off'
