beacon = get('deployment', 'beacon')
pod_spec = beacon['spec']['template']['spec']
assert [container['name'] for container in pod_spec['containers']] == ['beacon'], 'Keep the beacon container'
pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=beacon', '-o', 'json'))['items']
pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
assert len(pods) == 1, 'Exactly one beacon pod must run after the rollout'
if wants('no-host-namespaces'):
    assert not pod_spec.get('hostNetwork') and not pod_spec.get('hostPID') and not pod_spec.get('hostIPC'), 'Remove the host namespaces'
    assert not pods[0]['spec'].get('hostNetwork') and not pods[0]['spec'].get('hostPID'), 'The running pod must come from the new template'
if wants('no-host-path'):
    assert not any('hostPath' in volume for volume in pod_spec.get('volumes', [])), 'Remove the hostPath volume'
if wants('unprivileged-container'):
    for container in pod_spec['containers'] + pod_spec.get('initContainers', []):
        context = container.get('securityContext', {})
        assert not context.get('privileged'), 'The container must not be privileged'
        assert context.get('allowPrivilegeEscalation') is False, 'Turn privilege escalation off'
        assert context.get('runAsNonRoot') is True, 'Require a non-root user'
        assert context.get('capabilities', {}).get('drop') == ['ALL'], 'Drop all capabilities'
if wants('baseline-enforced'):
    labels = get('namespace', NAMESPACE, namespace=None)['metadata'].get('labels', {})
    assert labels.get('pod-security.kubernetes.io/enforce') == 'baseline', 'Enforce the baseline standard on ' + NAMESPACE
