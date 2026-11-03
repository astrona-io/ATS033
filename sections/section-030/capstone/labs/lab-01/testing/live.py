address=next(a['address'] for a in get('node','astro-ats-033-lab-030-capstone-01-control-plane',namespace='')['status']['addresses'] if a['type']=='InternalIP')
debug=get('service','probe-debug')
assert all('nodePort' not in port for port in debug['spec']['ports']),'probe-debug must not keep a node port'
public=get('service','probe-public')
assert [port.get('nodePort') for port in public['spec']['ports']]==[30081],'probe-public must keep node port 30081'
behavior_check({'args':['kubectl','-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+':19090/'],'denied':True,'failure_markers':['connection refused']})
behavior_check({'args':['kubectl','-n','outpost','exec','drifter','--','wget','-q','-T','3','-O-','http://'+address+':30080/'],'denied':True,'failure_markers':['connection refused','timed out']})
import re
kubelet_config=command(['podman','exec','astro-ats-033-lab-030-capstone-01-worker','cat','/var/lib/kubelet/config.yaml']).stdout
assert re.search(r'^authentication:\n  anonymous:\n    enabled: false$',kubelet_config,re.M),'The kubelet must reject anonymous requests'
assert re.search(r'^authorization:\n  mode: Webhook$',kubelet_config,re.M),'The kubelet authorization mode must be Webhook'
behavior_check({'args':['podman','exec','astro-ats-033-lab-030-capstone-01-worker','curl','-sk','-o','/dev/null','-w','%{http_code}','https://127.0.0.1:10250/pods'],'equals':'401'})
