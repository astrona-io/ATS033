import json
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=cargo','-o','json'))['items']
live=[p['metadata']['name'] for p in pods if 'deletionTimestamp' not in p['metadata'] and p['status'].get('phase')=='Running']
assert len(live)==1, 'Exactly one running cargo pod is required'
pod_name=live[0]
status=kubectl('-n','starfleet','exec',pod_name,'--','cat','/proc/1/status')
fields=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
assert fields['Seccomp'].strip()=='2' and fields['NoNewPrivs'].strip()=='1', 'Install the seccomp filter and block privilege escalation'
assert fields['CapBnd'].strip()=='0000000000000000', 'Drop every capability'
assert kubectl('-n','starfleet','exec',pod_name,'--','id','-u')=='1000', 'The process must run as user 1000'
assert kubectl('-n','starfleet','exec',pod_name,'--','sh','-c','printf allowed > /scratch/result; cat /scratch/result')=='allowed', 'The scratch volume must be writable'
for shell, marker in (('printf denied > /root-file','read-only file system'),('ln -s /scratch/result /scratch/link','operation not permitted')):
    result=command(['kubectl','-n','starfleet','exec',pod_name,'--','sh','-c',shell],success=False)
    assert result.returncode!=0 and marker in (result.stdout+result.stderr).lower(), 'Expected a denial: '+shell
