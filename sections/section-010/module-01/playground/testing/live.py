node=NODE
assert command([ENGINE,'exec',node,'systemctl','show','training-extra.service','--property=ActiveState','--value']).stdout.strip()=='inactive', 'Stop the unnecessary service'
assert command([ENGINE,'exec',node,'systemctl','show','training-extra.service','--property=UnitFileState','--value']).stdout.strip()=='disabled', 'Disable automatic startup'
assert command([ENGINE,'exec',node,'systemctl','is-active','kubelet']).stdout.strip()=='active'
assert command([ENGINE,'exec',node,'systemctl','is-active','containerd']).stdout.strip()=='active'
