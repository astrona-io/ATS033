PROFILE = 'profiles/block-delete.json'
BLOCKED_CALLS = {'unlink', 'unlinkat', 'rmdir'}


def effective_seccomp(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('seccompProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('seccompProfile') or {}


pod = get('pod', 'no-delete')
profile = effective_seccomp(pod, 'shell')
assert profile.get('type') == 'Localhost' and profile.get('localhostProfile') == PROFILE, 'no-delete must use the Localhost profile ' + PROFILE
if wants('no-delete-pod'):
    content = node_exec(NODE, 'cat', '/var/lib/kubelet/seccomp/' + PROFILE, success=False)
    assert content.returncode == 0, 'The profile file is missing on the node'
    document = json.loads(content.stdout)
    assert document.get('defaultAction') == 'SCMP_ACT_ALLOW', 'The default action must be SCMP_ACT_ALLOW'
    denied = set()
    for rule in document.get('syscalls') or []:
        if rule.get('action') == 'SCMP_ACT_ERRNO':
            denied.update(rule.get('names') or [])
    assert BLOCKED_CALLS <= denied, 'The profile must return SCMP_ACT_ERRNO for unlink, unlinkat and rmdir'
    status = kubectl('-n', NAMESPACE, 'exec', 'no-delete', '--', 'cat', '/proc/1/status')
    fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
    assert fields['Seccomp'].strip() == '2', 'The process in no-delete has no seccomp filter'
