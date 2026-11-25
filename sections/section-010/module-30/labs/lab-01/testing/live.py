# Cluster checks for this lab. check.py runs this file with its helpers in scope.
# Each outcome reads the Deployment template and then tests the running pod.
beacon = get('deployment', 'beacon')
pod_spec = beacon['spec']['template']['spec']
containers = pod_spec['containers']
assert [container['name'] for container in containers] == ['beacon'], 'Keep exactly one container named beacon'
container = containers[0]
assert container['image'] == 'docker.io/library/busybox:1.37.0', 'Keep the image docker.io/library/busybox:1.37.0'
assert container.get('command') == ['sh', '-c', 'sleep 3600'], 'Keep the command sh -c "sleep 3600"'

pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=beacon', '-o', 'json'))['items']
pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
assert len(pods) == 1, 'Exactly one beacon pod must run after the rollout'
pod = pods[0]
pod_ready = pod['status'].get('phase') == 'Running' and any(
    condition['type'] == 'Ready' and condition['status'] == 'True' for condition in pod['status'].get('conditions', []))
assert pod_ready, 'The beacon pod must be Running and Ready'
POD_NAME = pod['metadata']['name']


def run_in_pod(*args):
    return command(['kubectl', '-n', NAMESPACE, 'exec', POD_NAME, '-c', 'beacon', '--', *args], success=False)


container_context = container.get('securityContext', {})
pod_context = pod_spec.get('securityContext', {})


def effective(field):
    """A container setting wins over the same pod setting."""
    return container_context.get(field, pod_context.get(field))


if wants('no-host-namespaces'):
    for field in ('hostNetwork', 'hostPID', 'hostIPC'):
        assert not pod_spec.get(field), 'The template still sets ' + field + ': true'
    assert pod['status'].get('podIP') != pod['status'].get('hostIP'), 'The pod still uses the node network (pod IP equals node IP)'
    processes = run_in_pod('ps', '-o', 'comm')
    assert processes.returncode == 0, 'ps must run in the beacon container'
    assert 'kubelet' not in processes.stdout.split(), 'The pod still sees node processes such as kubelet'

if wants('scratch-volume'):
    volumes = pod_spec.get('volumes', [])
    assert not any('hostPath' in volume for volume in volumes), 'The template still mounts a hostPath volume'
    empty_dirs = {volume['name'] for volume in volumes if 'emptyDir' in volume}
    mounts = [mount for mount in container.get('volumeMounts', []) if mount['mountPath'] == '/scratch']
    assert mounts and mounts[0]['name'] in empty_dirs, 'Mount an emptyDir volume at /scratch'
    write = run_in_pod('sh', '-c', 'touch /scratch/grader-check && rm /scratch/grader-check')
    assert write.returncode == 0, 'The container cannot write to /scratch'

if wants('non-root-unprivileged'):
    assert not container_context.get('privileged'), 'The container is still privileged'
    assert container_context.get('allowPrivilegeEscalation') is False, 'Set allowPrivilegeEscalation: false'
    assert effective('runAsNonRoot') is True, 'Set runAsNonRoot: true'
    assert effective('runAsUser') == 10001, 'Run the container as user 10001'
    assert 'ALL' in container_context.get('capabilities', {}).get('drop', []), 'Drop all capabilities'
    user_id = run_in_pod('id', '-u')
    assert user_id.stdout.strip() == '10001', 'The process runs as user ' + user_id.stdout.strip() + ', not 10001'

if wants('read-only-root'):
    assert container_context.get('readOnlyRootFilesystem') is True, 'Set readOnlyRootFilesystem: true'
    write = run_in_pod('touch', '/grader-check')
    assert write.returncode != 0, 'The container can still write to its root filesystem'
