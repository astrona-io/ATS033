ETCD_HEALTH = [
    'curl', '-s', '-m', '5',
    '--cacert', '/etc/kubernetes/pki/etcd/ca.crt',
    '--cert', '/etc/kubernetes/pki/apiserver-etcd-client.crt',
    '--key', '/etc/kubernetes/pki/apiserver-etcd-client.key',
    'https://127.0.0.1:2379/health',
]

# Guards: etcd answers its health check and the API server is ready.
health = json.loads(node_exec(NODE, *ETCD_HEALTH).stdout)
assert health.get('health') == 'true', 'etcd must report healthy'
assert kubectl('get', '--raw', '/readyz') == 'ok', 'The API server must be ready'

if wants('etcd-data-directory-mode'):
    mode = node_exec(NODE, 'stat', '-c', '%a %U %G', '/var/lib/etcd').stdout.strip()
    assert mode == '700 root root', 'The etcd data directory must have mode 700 and owner root:root, found: ' + mode
