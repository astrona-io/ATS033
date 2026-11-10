control = NODE
worker = WORKER
assert command([ENGINE,'exec',control,'systemctl','show','training-extra.service','--property=ActiveState','--value']).stdout.strip() == 'inactive', 'Stop the unnecessary service'
assert command([ENGINE,'exec',control,'systemctl','show','training-extra.service','--property=UnitFileState','--value']).stdout.strip() == 'disabled', 'Disable automatic startup'
for host in (control, worker):
    assert command([ENGINE,'exec',host,'systemctl','is-active','kubelet']).stdout.strip() == 'active'
    assert command([ENGINE,'exec',host,'systemctl','is-active','containerd']).stdout.strip() == 'active'
ssh_text = command([ENGINE,'exec',worker,'sh','-c','cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config']).stdout
effective = {}
for line in ssh_text.splitlines():
    fields = line.split(None, 1)
    if len(fields) == 2 and not fields[0].startswith('#') and fields[0].lower() != 'include':
        effective.setdefault(fields[0].lower(), fields[1].strip())
assert effective.get('permitrootlogin') == 'no', 'Root login over SSH must be refused'
assert effective.get('passwordauthentication') == 'no', 'Password logins must be refused by the first value sshd reads'
assert effective.get('pubkeyauthentication') == 'yes', 'Key logins must stay on'
assert effective.get('allowusers') == 'opsadmin', 'Only opsadmin may log in'
old_user = command([ENGINE,'exec',worker,'getent','passwd','olduser']).stdout.strip().split(':')
assert old_user[6] == '/usr/sbin/nologin', 'Give olduser a shell that refuses logins'
assert command([ENGINE,'exec',worker,'passwd','-S','olduser']).stdout.split()[1] == 'L', 'Lock the password of olduser'
ops_user = command([ENGINE,'exec',worker,'getent','passwd','opsadmin']).stdout.strip().split(':')
assert ops_user[6] == '/bin/bash', 'opsadmin must keep its login shell'
assert command([ENGINE,'exec',worker,'systemctl','is-active','kubelet']).stdout.strip() == 'active'
assert command([ENGINE,'exec',worker,'systemctl','is-active','containerd']).stdout.strip() == 'active'
beacon = get('deployment', 'beacon')
pod_spec = beacon['spec']['template']['spec']
assert not pod_spec.get('hostNetwork') and not pod_spec.get('hostPID') and not pod_spec.get('hostIPC'), 'Remove the host namespaces'
assert not any('hostPath' in volume for volume in pod_spec.get('volumes', [])), 'Remove the hostPath volume'
assert [container['name'] for container in pod_spec['containers']] == ['beacon'], 'Keep the beacon container'
for container in pod_spec['containers'] + pod_spec.get('initContainers', []):
    context = container.get('securityContext', {})
    assert not context.get('privileged'), 'The container must not be privileged'
    assert context.get('allowPrivilegeEscalation') is False, 'Turn privilege escalation off'
    assert context.get('runAsNonRoot') is True, 'Require a non-root user'
    assert context.get('capabilities', {}).get('drop') == ['ALL'], 'Drop all capabilities'
pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=beacon', '-o', 'json'))['items']
pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
assert len(pods) == 1 and not pods[0]['spec'].get('hostNetwork') and not pods[0]['spec'].get('hostPID'), 'The running pod must come from the new template'
labels = get('namespace', 'starfleet', namespace=None)['metadata'].get('labels', {})
assert labels.get('pod-security.kubernetes.io/enforce') == 'baseline', 'Enforce the baseline standard on starfleet'
ledger = get('deployment', 'ledger')
ledger_spec = ledger['spec']['template']['spec']
assert ledger_spec.get('nodeSelector') == {'node-restriction.kubernetes.io/dedicated': 'ledger'}, 'Select the dedicated node with its label'
assert any(item.get('key') == 'dedicated' and item.get('value') == 'ledger' and item.get('effect') == 'NoSchedule' for item in ledger_spec.get('tolerations', [])), 'Tolerate the dedicated taint'
worker_node = get('node', worker, namespace=None)
assert worker_node['metadata'].get('labels', {}).get('node-restriction.kubernetes.io/dedicated') == 'ledger', 'Label the worker node'
assert any(item.get('key') == 'dedicated' and item.get('value') == 'ledger' and item.get('effect') == 'NoSchedule' for item in worker_node['spec'].get('taints', [])), 'Taint the worker node'
ledger_pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=ledger', '-o', 'json'))['items']
ledger_pods = [pod for pod in ledger_pods if not pod['metadata'].get('deletionTimestamp')]
assert len(ledger_pods) == 1 and ledger_pods[0]['spec'].get('nodeName') == worker, 'The ledger pod must run on the dedicated node'
