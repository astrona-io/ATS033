SCHEDULER_POD = 'kube-scheduler-' + NODE

# Guards: the scheduler static pod is Ready and the shuttle pod runs on the worker.
ready = kubectl('-n', 'kube-system', 'get', 'pod', SCHEDULER_POD, '-o', 'jsonpath={.status.conditions[?(@.type=="Ready")].status}')
assert ready == 'True', 'The kube-scheduler pod must be Ready'
assert get('pod', 'shuttle')['spec'].get('nodeName') == WORKER, 'The shuttle pod must run on the worker node'

if wants('scheduler-loopback-listener'):
    process = node_exec(NODE, 'pgrep', '-a', 'kube-scheduler').stdout
    assert '--bind-address=127.0.0.1' in process, 'The running kube-scheduler must use --bind-address=127.0.0.1'
    listeners = [line.split()[3] for line in node_exec(NODE, 'ss', '-tln').stdout.splitlines()[1:] if line.split()[3].endswith(':10259')]
    assert listeners == ['127.0.0.1:10259'], 'Port 10259 must listen on 127.0.0.1 only'
    behavior_check({'args': [ENGINE, 'exec', NODE, 'curl', '-sk', '-m', '5', 'https://127.0.0.1:10259/healthz'], 'equals': 'ok'})

if wants('scheduler-port-closed'):
    node_ip = kubectl('get', 'node', NODE, '-o', 'jsonpath={.status.addresses[?(@.type=="InternalIP")].address}')
    behavior_check({
        'args': ['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'https://' + node_ip + ':10259/healthz'],
        'denied': True,
        'failure_markers': ['connection refused'],
    })
