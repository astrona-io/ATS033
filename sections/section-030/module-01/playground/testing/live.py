assert get('pod','node-local-server')['spec'].get('nodeName')==NODE, 'Run node-local-server on the control-plane node'
address=next(address['address'] for address in get('node',NODE,namespace='')['status']['addresses'] if address['type']=='InternalIP')
behavior_check({'args':['kubectl','-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+':19090/'],'denied':True,'failure_markers':['connection refused']})
