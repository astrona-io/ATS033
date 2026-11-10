import re
assert kubectl('get', 'node', WORKER, '-o', 'jsonpath={.status.conditions[?(@.type=="Ready")].status}') == 'True', 'The worker node must stay Ready'
kubelet_config = command([ENGINE, 'exec', WORKER, 'cat', '/var/lib/kubelet/config.yaml']).stdout
if wants('anonymous-auth-disabled'):
    assert re.search(r'^authentication:\n  anonymous:\n    enabled: false$', kubelet_config, re.M), 'The kubelet must reject anonymous requests'
    behavior_check({'args': [ENGINE, 'exec', WORKER, 'curl', '-sk', '-o', '/dev/null', '-w', '%{http_code}', 'https://127.0.0.1:10250/pods'], 'equals': '401'})
if wants('webhook-authorization'):
    assert re.search(r'^authorization:\n  mode: Webhook$', kubelet_config, re.M), 'The kubelet authorization mode must be Webhook'
