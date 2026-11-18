PROFILE_NAME = 'k8s-deny-etc-write'


def loaded_mode(node, profile_name):
    """Read the mode of a loaded profile from the kernel list of that node."""
    listing = node_exec(node, 'cat', '/sys/kernel/security/apparmor/profiles', success=False)
    assert listing.returncode == 0, 'The AppArmor interface is missing on ' + node
    for line in listing.stdout.splitlines():
        name, _, mode = line.rpartition(' ')
        if name == profile_name:
            return mode.strip('()')
    return None


pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=scout', '-o', 'json'))['items']
assert len(pods) == 1 and 'deletionTimestamp' not in pods[0]['metadata'], 'Exactly one scout pod must exist'
pod = pods[0]
pod_name = pod['metadata']['name']
container = next((item for item in pod['spec']['containers'] if item['name'] == 'scout'), None)
assert container is not None, 'Keep the container named scout'
profile = (container.get('securityContext') or {}).get('appArmorProfile') or (pod['spec'].get('securityContext') or {}).get('appArmorProfile') or {}
assert profile.get('type') == 'Localhost' and profile.get('localhostProfile') == PROFILE_NAME, 'scout must keep the Localhost AppArmor profile ' + PROFILE_NAME

if wants('profile-enforced'):
    mode = loaded_mode(NODE, PROFILE_NAME)
    assert mode == 'enforce', PROFILE_NAME + ' on ' + NODE + ' is in mode ' + str(mode)
if wants('scout-etc-write-denied'):
    current = kubectl('-n', NAMESPACE, 'exec', pod_name, '--', 'cat', '/proc/1/attr/current').strip()
    assert current == PROFILE_NAME + ' (enforce)', 'The scout process runs under ' + current
    written = command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '--', 'touch', '/etc/scout-check'], success=False)
    assert written.returncode != 0 and 'permission denied' in (written.stdout + written.stderr).lower(), 'Writing under /etc must fail with Permission denied'
