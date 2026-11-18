PROFILE_NAME = 'k8s-deny-tmp-write'


def effective_apparmor(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('appArmorProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('appArmorProfile') or {}


def current_profile(container_name):
    """Read the AppArmor label of the main process in one container."""
    return kubectl('-n', NAMESPACE, 'exec', 'bridge', '-c', container_name, '--', 'cat', '/proc/1/attr/current').strip()


pod = get('pod', 'bridge')
assert 'deletionTimestamp' not in pod['metadata'], 'The bridge pod is being deleted'
conditions = {item['type']: item['status'] for item in pod.get('status', {}).get('conditions', [])}
assert conditions.get('Ready') == 'True', 'The bridge pod must be ready'
pod_profile = (pod['spec'].get('securityContext') or {}).get('appArmorProfile') or {}
assert pod_profile.get('type') == 'RuntimeDefault', 'The pod-level AppArmor profile must be RuntimeDefault'
assert effective_apparmor(pod, 'console').get('type') == 'RuntimeDefault', 'console must use the RuntimeDefault AppArmor profile'
logger_profile = effective_apparmor(pod, 'logger')
assert logger_profile.get('type') == 'Localhost' and logger_profile.get('localhostProfile') == PROFILE_NAME, 'logger must use the Localhost AppArmor profile ' + PROFILE_NAME

if wants('console-tmp-write-works'):
    current = current_profile('console')
    assert current.endswith('(enforce)') and not current.startswith(PROFILE_NAME), 'The console process runs under ' + current
    written = command(['kubectl', '-n', NAMESPACE, 'exec', 'bridge', '-c', 'console', '--', 'touch', '/tmp/console-check'], success=False)
    assert written.returncode == 0, 'Writing under /tmp in console must work'
if wants('logger-tmp-write-denied'):
    current = current_profile('logger')
    assert current == PROFILE_NAME + ' (enforce)', 'The logger process runs under ' + current
    written = command(['kubectl', '-n', NAMESPACE, 'exec', 'bridge', '-c', 'logger', '--', 'touch', '/tmp/logger-check'], success=False)
    assert written.returncode != 0 and 'permission denied' in (written.stdout + written.stderr).lower(), 'Writing under /tmp in logger must fail with Permission denied'
