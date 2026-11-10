address=next(a['address'] for a in get('node',NODE,namespace='')['status']['addresses'] if a['type']=='InternalIP')
admin=get('service','probe-admin')
assert all('nodePort' not in port for port in admin['spec']['ports']),'probe-admin must not keep a node port'
behavior_check({'args':['kubectl','-n','outpost','exec','drifter','--','wget','-q','-T','3','-O-','http://'+address+':30090/'],'denied':True,'failure_markers':['connection refused','timed out']})
