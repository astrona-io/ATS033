status=kubectl('-n','starfleet','exec','restricted-reader','--','cat','/proc/1/status')
fields=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
assert fields['Seccomp'].strip()=='2' and fields['NoNewPrivs'].strip()=='1', 'Install an actual seccomp filter and no-new-privileges boundary'
# The ServiceAccount token adds a volume and a mount, so look these up by name.
pod=json.loads(kubectl('-n','starfleet','get','pod','restricted-reader','-o','json'))
volumes={volume['name']: volume for volume in pod['spec'].get('volumes',[])}
assert 'emptyDir' in volumes.get('scratch',{}), 'Add an emptyDir volume named scratch'
mounts={mount['name']: mount['mountPath'] for mount in pod['spec']['containers'][0].get('volumeMounts',[])}
assert mounts.get('scratch')=='/scratch', 'Mount the scratch volume at /scratch'
