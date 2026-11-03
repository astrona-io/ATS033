import json
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=relay','-o','json'))['items']
live=[p['metadata']['name'] for p in pods if 'deletionTimestamp' not in p['metadata'] and p['status'].get('phase')=='Running']
assert len(live)==1, 'Exactly one running relay pod is required'
pod_name=live[0]
status=kubectl('-n','starfleet','exec',pod_name,'--','cat','/proc/1/status')
fields=dict(line.split(':',1) for line in status.splitlines() if ':' in line)
assert fields['CapBnd'].strip()=='0000000000000400' and fields['NoNewPrivs'].strip()=='1' and fields['Seccomp'].strip()=='2', 'Keep only NET_BIND_SERVICE, block escalation and install the seccomp filter'
assert kubectl('-n','starfleet','exec',pod_name,'--','id','-u')=='1000', 'The process must run as user 1000'
