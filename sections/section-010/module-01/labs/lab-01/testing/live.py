def unit(prop):
    return command([ENGINE,'exec',NODE,'systemctl','show','training-extra.service','--property='+prop,'--value']).stdout.strip()
assert command([ENGINE,'exec',NODE,'systemctl','is-active','kubelet']).stdout.strip()=='active', 'The kubelet must stay active'
assert command([ENGINE,'exec',NODE,'systemctl','is-active','containerd']).stdout.strip()=='active', 'containerd must stay active'
if wants('service-stopped'):
    assert unit('ActiveState')=='inactive', 'Stop the unnecessary service training-extra.service'
if wants('service-disabled'):
    assert unit('UnitFileState')=='disabled', 'Disable automatic startup of training-extra.service'
