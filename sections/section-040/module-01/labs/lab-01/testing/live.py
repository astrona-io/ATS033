status = kubectl('-n', NAMESPACE, 'exec', 'restricted-reader', '--', 'cat', '/proc/1/status')
fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
if wants('reader-seccomp'):
    assert fields['Seccomp'].strip() == '2', 'Install an actual seccomp filter'
if wants('reader-container-hardening'):
    assert fields['NoNewPrivs'].strip() == '1', 'Set the no-new-privileges boundary'
if wants('reader-scratch-volume'):
    # The ServiceAccount token adds a volume and a mount, so look these up by name.
    pod = get('pod', 'restricted-reader')
    volumes = {volume['name']: volume for volume in pod['spec'].get('volumes', [])}
    assert 'emptyDir' in volumes.get('scratch', {}), 'Add an emptyDir volume named scratch'
    mounts = {mount['name']: mount['mountPath'] for mount in pod['spec']['containers'][0].get('volumeMounts', [])}
    assert mounts.get('scratch') == '/scratch', 'Mount the scratch volume at /scratch'
