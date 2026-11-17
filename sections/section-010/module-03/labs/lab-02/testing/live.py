# Cluster checks for this lab. check.py runs this file with its helpers in scope.
HOST_FIELDS = ('hostNetwork', 'hostPID', 'hostIPC')
PRIVILEGED_POD = json.dumps({
    'apiVersion': 'v1',
    'spec': {'containers': [{
        'name': 'admission-check',
        'image': 'docker.io/library/busybox:1.37.0',
        'command': ['sh', '-c', 'sleep 3600'],
        'securityContext': {'privileged': True},
    }]},
})

if wants('baseline-enforced'):
    labels = get('namespace', NAMESPACE, namespace=None)['metadata'].get('labels', {})
    level = labels.get('pod-security.kubernetes.io/enforce')
    assert level == 'baseline', 'The namespace label pod-security.kubernetes.io/enforce is ' + str(level) + ', not baseline'
    # A server-side dry run sends the pod through admission without storing it.
    attempt = command(['kubectl', '-n', NAMESPACE, 'run', 'admission-check', '--image=docker.io/library/busybox:1.37.0',
                       '--restart=Never', '--dry-run=server', '--overrides=' + PRIVILEGED_POD], success=False)
    assert attempt.returncode != 0, 'The API server still accepts a privileged pod in ' + NAMESPACE
    assert 'PodSecurity' in attempt.stderr, 'The privileged pod was rejected, but not by Pod Security Admission: ' + attempt.stderr.strip()

if wants('tracker-without-host-access'):
    tracker = get('deployment', 'tracker')
    pod_spec = tracker['spec']['template']['spec']
    for field in HOST_FIELDS:
        assert not pod_spec.get(field), 'The tracker template still sets ' + field + ': true'
    for container in pod_spec['containers'] + pod_spec.get('initContainers', []):
        assert not container.get('securityContext', {}).get('privileged'), 'The tracker container must not be privileged'
    assert [container['image'] for container in pod_spec['containers']] == ['docker.io/library/busybox:1.37.0'], 'Keep the tracker image'
    replicas = tracker['spec'].get('replicas', 1)
    status = tracker.get('status', {})
    assert status.get('observedGeneration', 0) >= tracker['metadata']['generation'], 'The Deployment controller has not seen the change yet'
    for field in ('updatedReplicas', 'readyReplicas', 'availableReplicas'):
        assert status.get(field, 0) == replicas, 'The tracker rollout is not complete (' + field + ' is ' + str(status.get(field, 0)) + ')'
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=tracker', '-o', 'json'))['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    assert len(pods) == replicas, 'Old tracker pods are still running'
    for pod in pods:
        assert not any(pod['spec'].get(field) for field in HOST_FIELDS), 'Pod ' + pod['metadata']['name'] + ' still uses a host namespace'
