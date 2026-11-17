OUTPOST = 'outpost-033-030-01-03'
PROBE_URL = 'http://probe.' + NAMESPACE + '.svc.cluster.local/'


def request(namespace, pod, url):
    return ['kubectl', '-n', namespace, 'exec', pod, '--', 'wget', '-q', '-T', '3', '-O-', url]


def is_default_deny_ingress(policy):
    spec = policy.get('spec', {})
    return spec.get('podSelector') in ({}, None) and 'Ingress' in spec.get('policyTypes', []) and not spec.get('ingress')


if wants('default-deny-ingress'):
    policies = json.loads(kubectl('-n', NAMESPACE, 'get', 'networkpolicy', '-o', 'json'))['items']
    assert any(is_default_deny_ingress(policy) for policy in policies), 'The namespace needs a NetworkPolicy that selects every pod and denies all ingress'
    beacon_url = 'http://' + get('pod', 'beacon')['status']['podIP'] + ':8080/'
    behavior_check({'args': request(OUTPOST, 'drifter', beacon_url), 'denied': True, 'failure_markers': ['timed out']})
    behavior_check({'args': request(NAMESPACE, 'shuttle', beacon_url), 'denied': True, 'failure_markers': ['timed out']})

if wants('shuttle-to-probe-only'):
    behavior_check({'args': request(NAMESPACE, 'shuttle', PROBE_URL), 'contains': ['version=v1']})
    behavior_check({'args': request(OUTPOST, 'drifter', PROBE_URL), 'denied': True, 'failure_markers': ['timed out']})
