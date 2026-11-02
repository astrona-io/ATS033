address=next(address['address'] for address in get('node','astro-ats-033-lab-030-01-01-control-plane',namespace='')['status']['addresses'] if address['type']=='InternalIP')
behavior_check({'args':['kubectl','-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+':19090/'],'denied':True,'failure_markers':['connection refused']})
