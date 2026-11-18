# Node checks for this lab. check.py runs this file with its helpers in scope.
UNIT = 'remote-diag.service'
PORT = '8099'


def unit_property(name):
    return node_exec(NODE, 'systemctl', 'show', UNIT, '--property=' + name, '--value').stdout.strip()


def port_is_listening():
    listeners = node_exec(NODE, 'ss', '-Htln').stdout.splitlines()
    return any(line.split()[3].rsplit(':', 1)[-1] == PORT for line in listeners if len(line.split()) > 3)


states = node_exec(NODE, 'systemctl', 'is-active', 'kubelet.service', 'containerd.service', success=False).stdout.split()
assert states == ['active', 'active'], 'kubelet and containerd must stay active on ' + NODE

if wants('listener-closed'):
    assert unit_property('ActiveState') not in ('active', 'activating', 'reloading'), UNIT + ' is still running'
    assert not port_is_listening(), 'A process still listens on TCP port ' + PORT

if wants('boot-start-removed'):
    load_state = unit_property('LoadState')
    file_state = unit_property('UnitFileState')
    assert load_state in ('not-found', 'masked') or file_state in ('disabled', 'masked'), UNIT + ' still starts at boot (unit file state: ' + (file_state or load_state) + ')'
