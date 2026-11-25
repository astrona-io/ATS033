PROFILE_NAME = 'k8s-deny-tmp-write'


def effective_apparmor(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('appArmorProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('appArmorProfile') or {}


def loaded_mode(node, profile_name):
    """Read the mode of a loaded profile from the kernel list of that node."""
    listing = node_exec(node, 'cat', '/sys/kernel/security/apparmor/profiles', success=False)
    assert listing.returncode == 0, 'The AppArmor interface is missing on ' + node
    for line in listing.stdout.splitlines():
        name, _, mode = line.rpartition(' ')
        if name == profile_name:
            return mode.strip('()')
    return None


pod = get('pod', 'scout')
profile = effective_apparmor(pod, 'scout')
assert profile.get('type') == 'Localhost' and profile.get('localhostProfile') == PROFILE_NAME, 'scout must use the Localhost AppArmor profile ' + PROFILE_NAME

if wants('profile-loaded-in-enforce-mode'):
    assert loaded_mode(NODE, PROFILE_NAME) == 'enforce', PROFILE_NAME + ' is not loaded in enforce mode on ' + NODE
if wants('scout-confined'):
    current = kubectl('-n', NAMESPACE, 'exec', 'scout', '--', 'cat', '/proc/1/attr/current').strip()
    assert current == PROFILE_NAME + ' (enforce)', 'The scout process runs under ' + current
if wants('scout-tmp-write-denied'):
    written = command(['kubectl', '-n', NAMESPACE, 'exec', 'scout', '--', 'touch', '/tmp/scout-check'], success=False)
    assert written.returncode != 0 and 'permission denied' in (written.stdout + written.stderr).lower(), 'Writing under /tmp must fail with Permission denied'
