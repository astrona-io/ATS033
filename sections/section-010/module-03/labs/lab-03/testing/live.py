# Cluster checks for this lab. check.py runs this file with its helpers in scope.
import time

LABEL_KEY = 'node-restriction.kubernetes.io/dedicated'
CHECK_POD = 'visitor-check'


def node_object(name):
    return get('node', name, namespace=None)


def has_dedicated_taint(node):
    return any(taint.get('key') == 'dedicated' and taint.get('value') == 'ledger' and taint.get('effect') == 'NoSchedule'
               for taint in node['spec'].get('taints', []))


def visitor_is_unschedulable():
    """Create a pod that asks for the worker but has no toleration, and report whether the scheduler refuses it."""
    command(['kubectl', '-n', NAMESPACE, 'delete', 'pod', CHECK_POD, '--ignore-not-found', '--wait=false'], success=False)
    overrides = json.dumps({'apiVersion': 'v1', 'spec': {'nodeSelector': {'kubernetes.io/hostname': WORKER}}})
    command(['kubectl', '-n', NAMESPACE, 'run', CHECK_POD, '--image=docker.io/library/busybox:1.37.0', '--restart=Never',
             '--labels=app=visitor-check', '--overrides=' + overrides, '--command', '--', 'sh', '-c', 'sleep 30'])
    try:
        for attempt in range(15):
            pod = get('pod', CHECK_POD)
            for condition in pod['status'].get('conditions', []):
                if condition['type'] == 'PodScheduled':
                    if condition['status'] == 'True':
                        return False
                    if condition.get('reason') == 'Unschedulable':
                        return True
            time.sleep(1)
        return False
    finally:
        command(['kubectl', '-n', NAMESPACE, 'delete', 'pod', CHECK_POD, '--ignore-not-found', '--wait=false',
                 '--grace-period=0', '--force'], success=False)


def is_ready(pod):
    return pod['status'].get('phase') == 'Running' and any(
        condition['type'] == 'Ready' and condition['status'] == 'True' for condition in pod['status'].get('conditions', []))


def tolerates_dedicated(toleration):
    if toleration.get('effect') not in (None, '', 'NoSchedule'):
        return False
    if toleration.get('operator') == 'Exists':
        return toleration.get('key') in (None, '', 'dedicated')
    return toleration.get('key') == 'dedicated' and toleration.get('value') == 'ledger'


def selects_dedicated(pod_spec):
    if pod_spec.get('nodeSelector', {}).get(LABEL_KEY) == 'ledger':
        return True
    required = pod_spec.get('affinity', {}).get('nodeAffinity', {}).get('requiredDuringSchedulingIgnoredDuringExecution', {})
    terms = required.get('nodeSelectorTerms', [])
    return bool(terms) and all(
        any(expression.get('key') == LABEL_KEY and expression.get('operator') == 'In' and expression.get('values') == ['ledger']
            for expression in term.get('matchExpressions', []))
        for term in terms)


if wants('worker-dedicated'):
    worker = node_object(WORKER)
    assert worker['metadata'].get('labels', {}).get(LABEL_KEY) == 'ledger', WORKER + ' has no label ' + LABEL_KEY + '=ledger'
    assert has_dedicated_taint(worker), WORKER + ' has no taint dedicated=ledger:NoSchedule'
    other_worker = node_object(WORKER + '2')
    assert not has_dedicated_taint(other_worker), 'Only ' + WORKER + ' may be dedicated; remove the taint from ' + WORKER + '2'
    assert visitor_is_unschedulable(), 'A pod without the toleration can still be scheduled onto ' + WORKER

if wants('ledger-pinned'):
    ledger = get('deployment', 'ledger')
    pod_spec = ledger['spec']['template']['spec']
    assert any(tolerates_dedicated(toleration) for toleration in pod_spec.get('tolerations', [])), 'The ledger template has no toleration for dedicated=ledger:NoSchedule'
    assert selects_dedicated(pod_spec), 'The ledger template does not require the node label ' + LABEL_KEY + '=ledger'
    replicas = ledger['spec'].get('replicas', 1)
    assert replicas >= 2, 'Keep at least 2 ledger replicas'
    status = ledger.get('status', {})
    assert status.get('observedGeneration', 0) >= ledger['metadata']['generation'], 'The Deployment controller has not seen the change yet'
    assert status.get('updatedReplicas', 0) == replicas and status.get('readyReplicas', 0) == replicas, 'The ledger rollout is not complete'
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=ledger', '-o', 'json'))['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    assert len(pods) == replicas, 'Old ledger pods are still running'
    for pod in pods:
        assert pod['spec'].get('nodeName') == WORKER, 'Pod ' + pod['metadata']['name'] + ' runs on ' + str(pod['spec'].get('nodeName')) + ', not on ' + WORKER
        assert is_ready(pod), 'Pod ' + pod['metadata']['name'] + ' is not Ready'
