PROFILE = 'profiles/scout-guard.json'


def effective_seccomp(pod, container_name):
    """The container value overrides the pod value."""
    container = next((item for item in pod['spec']['containers'] if item['name'] == container_name), None)
    assert container is not None, 'Keep the container named ' + container_name
    own = (container.get('securityContext') or {}).get('seccompProfile')
    return own or (pod['spec'].get('securityContext') or {}).get('seccompProfile') or {}


pod = get('pod', 'scout')
profile = effective_seccomp(pod, pod['spec']['containers'][0]['name'])
uses_profile = profile.get('type') == 'Localhost' and profile.get('localhostProfile') == PROFILE
if wants('scout-localhost-profile'):
    installed = node_exec(NODE, 'cmp', '/opt/course/seccomp/scout-guard.json', '/var/lib/kubelet/seccomp/' + PROFILE, success=False)
    assert installed.returncode == 0, 'Install the profile at /var/lib/kubelet/seccomp/' + PROFILE
    assert uses_profile, 'Select the Localhost profile ' + PROFILE + ' for the scout container'
    status = kubectl('-n', NAMESPACE, 'exec', 'scout', '--', 'cat', '/proc/1/status')
    fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
    assert fields['Seccomp'].strip() == '2', 'The scout process has no seccomp filter'
if wants('scout-mkdir-blocked'):
    assert uses_profile, 'The mkdir denial must come from the Localhost profile ' + PROFILE
