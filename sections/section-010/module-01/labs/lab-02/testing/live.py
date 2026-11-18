# Node checks for this lab. check.py runs this file with its helpers in scope.
PACKAGE = 'debug-relay'
PORT = '7070'


def package_status():
    """The dpkg status words, or an empty string when dpkg has no record."""
    result = node_exec(NODE, 'dpkg-query', '-W', '-f=${Status}', PACKAGE, success=False)
    return result.stdout.strip() if result.returncode == 0 else ''


def path_exists(path):
    return node_exec(NODE, 'test', '-e', path, success=False).returncode == 0


def port_is_listening():
    listeners = node_exec(NODE, 'ss', '-Htln').stdout.splitlines()
    return any(line.split()[3].rsplit(':', 1)[-1] == PORT for line in listeners if len(line.split()) > 3)


states = node_exec(NODE, 'systemctl', 'is-active', 'kubelet.service', 'containerd.service', success=False).stdout.split()
assert states == ['active', 'active'], 'kubelet and containerd must stay active on ' + NODE
nodes = json.loads(kubectl('get', 'nodes', '-o', 'json'))['items']
for item in nodes:
    ready = [condition['status'] for condition in item['status']['conditions'] if condition['type'] == 'Ready']
    assert ready == ['True'], 'Node ' + item['metadata']['name'] + ' must stay Ready'

status = package_status()

if wants('package-removed'):
    assert status not in ('install ok installed', 'hold ok installed'), PACKAGE + ' is still installed (dpkg status: ' + status + ')'
    assert not path_exists('/usr/sbin/debug-relay'), 'The program /usr/sbin/debug-relay is still on the node'
    assert not port_is_listening(), 'A process still listens on TCP port ' + PORT

if wants('configuration-purged'):
    assert status in ('', 'unknown ok not-installed', 'purge ok not-installed'), PACKAGE + ' still has a dpkg record (dpkg status: ' + status + ')'
    assert not path_exists('/etc/debug-relay/relay.conf'), 'The configuration file /etc/debug-relay/relay.conf is still on the node'
