address=next(a['address'] for a in get('node','astro-ats-033-lab-030-02-01-control-plane',namespace='')['status']['addresses'] if a['type']=='InternalIP')
debug=get('service','probe-debug')
assert all('nodePort' not in port for port in debug['spec']['ports']),'probe-debug must not keep a node port'
public=get('service','probe-public')
assert [port.get('nodePort') for port in public['spec']['ports']]==[30081],'probe-public must keep node port 30081'
behavior_check({'args':['kubectl','-n','outpost','exec','drifter','--','wget','-q','-T','3','-O-','http://'+address+':30080/'],'denied':True,'failure_markers':['connection refused','timed out']})
