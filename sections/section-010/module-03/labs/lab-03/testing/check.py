#!/usr/bin/env python3
"""Grade a lab: resource contracts, bounded behavior checks and live.py.

Run with no argument to grade the whole lab, or with an outcome id to grade
one outcome. Each entry in requirements.json and each `if wants(...)` block
in live.py belongs to one outcome; an entry without an outcome is a guard
and runs for every outcome. config.yaml lists one validation script per
outcome (validation/validate-<id>.sh), each with its points. Like ATS020's
graders it prints one `PASS:` or `FAIL:` line.

Every run first checks that kubectl's current context is the lab's own:
ASTRONA_KUBE_CONTEXT when astrona sets it (an exam cluster sets its own),
otherwise the lab mode context in requirements.json. The node containers'
names and the container engine come from the environment astrona sets too,
so the same checks run on the lab's own cluster and on an exam cluster.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

DIRECTORY = Path(__file__).resolve().parent
REQUIREMENTS = json.loads((DIRECTORY / 'requirements.json').read_text())
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or REQUIREMENTS['context']
CLUSTER = os.environ.get('ASTRONA_KIND_CLUSTER') or REQUIREMENTS['cluster']
ENGINE = os.environ.get('ASTRONA_CONTAINER_ENGINE') or 'podman'
NAMESPACE = REQUIREMENTS['namespace']
NODE = CLUSTER + '-control-plane'
WORKER = CLUSTER + '-worker'
SELECTED = sys.argv[1] if len(sys.argv) > 1 else None
MATCHED = set()


def wants(outcome):
    """True when this outcome is being graded (or the whole lab is)."""
    if SELECTED is None or SELECTED == outcome:
        MATCHED.add(outcome)
        return True
    return False


def selected(check):
    outcome = check.get('outcome')
    return outcome is None or wants(outcome)


def command(args, *, success=True):
    result = subprocess.run(args, capture_output=True, text=True, timeout=20)
    if success:
        assert result.returncode == 0, 'Required command failed: ' + args[0]
    return result


def kubectl(*args):
    return command(['kubectl', *args]).stdout.strip()


def node_exec(node, *args, success=True):
    """Run a command inside a node container (NODE or WORKER)."""
    return command([ENGINE, 'exec', node, *args], success=success)


def get(kind, name, namespace=NAMESPACE):
    scope = ['-n', namespace] if namespace else []
    result = command(['kubectl', *scope, 'get', kind, name, '-o', 'json'], success=False)
    assert result.returncode == 0, f'Missing {kind} {name}' + (f' in namespace {namespace}' if namespace else '')
    return json.loads(result.stdout)


def contains(actual, expected):
    """Allow server-defaulted fields while preserving declared fields and lists."""
    if isinstance(expected, dict):
        return isinstance(actual, dict) and all(key in actual and contains(actual[key], value) for key, value in expected.items())
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(contains(left, right) for left, right in zip(actual, expected))
    return actual == expected


def resource_check(check):
    resource = get(check['kind'], check['name'], check.get('namespace', NAMESPACE))
    assert contains(resource, check['expected']), 'Required resource fields differ: ' + check['name']
    state = check.get('state')
    status = resource.get('status', {})
    if state == 'deployment':
        replicas = resource['spec'].get('replicas', 1)
        assert status.get('observedGeneration', 0) >= resource['metadata']['generation'], 'Current generation has not been observed'
        assert all(status.get(field, 0) == replicas for field in ('replicas', 'updatedReplicas', 'readyReplicas', 'availableReplicas')), 'Deployment rollout is incomplete'
    elif state == 'pod':
        assert status.get('phase') == 'Running' and any(condition['type'] == 'Ready' and condition['status'] == 'True' for condition in status.get('conditions', [])), 'Pod must be running and ready'
    elif state == 'job':
        assert status.get('succeeded', 0) == 1 and any(condition['type'] == 'Complete' and condition['status'] == 'True' for condition in status.get('conditions', [])), 'Job must complete successfully'
    elif state == 'pvc':
        assert status.get('phase') == 'Bound' and resource['spec'].get('volumeName'), 'Claim must bind to a volume'
    elif state == 'daemonset':
        desired = status.get('desiredNumberScheduled', 0)
        assert desired >= 2 and status.get('numberReady', 0) == desired and status.get('updatedNumberScheduled', 0) == desired, 'DaemonSet must cover both eligible nodes'
    return resource


def behavior_check(check):
    result = command(check['args'], success=not check.get('denied', False))
    if check.get('denied'):
        assert result.returncode == 1, 'Expected a bounded denied request, not a successful request or execution error'
        output = result.stdout + result.stderr
        assert any(marker in output.lower() for marker in check['failure_markers']), 'Request did not fail for the required reason'
    output = result.stdout.strip()
    if 'equals' in check:
        assert output == check['equals'], 'Command returned an unexpected value'
    for marker in check.get('contains', []):
        assert marker in output, 'Command did not return the expected application evidence'
    if 'json' in check:
        assert contains(json.loads(output), check['json']), 'Command returned an unexpected JSON contract'
    return result


def main():
    if kubectl('config', 'current-context') != CONTEXT:
        sys.exit('Refusing to operate on another Kubernetes context')
    for check in REQUIREMENTS.get('resources', []):
        if selected(check):
            resource_check(check)
    for check in REQUIREMENTS.get('behavior', []):
        if selected(check):
            behavior_check(check)
    extra = DIRECTORY / 'live.py'
    if extra.exists():
        exec(compile(extra.read_text(), str(extra), 'exec'), globals())
    assert SELECTED is None or SELECTED in MATCHED, 'Unknown outcome: ' + SELECTED
    print('PASS: ' + (SELECTED or 'every outcome'))


if __name__ == '__main__':
    try:
        main()
    except (AssertionError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print('FAIL: ' + str(error))
        sys.exit(1)
