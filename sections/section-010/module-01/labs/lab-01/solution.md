---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Disable An Unneeded Node Service Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-01" || exit 1
node_name="astro-ats-033-lab-010-01-01-control-plane"
worker_name="astro-ats-033-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Disable and stop only training-extra.service on this private control-plane container. Record host-review with service training-extra.service and result disabled. The extra service must be inactive and disabled, while kubelet and containerd remain active and API readiness succeeds. This is a scoped host-service exercise, not a full host hardening assessment.

Save this as `configmap-host-review.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: host-review
  namespace: starfleet
data:
  service: training-extra.service
  result: disabled
```

Save this as `disable-service.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-lab-010-01-01"
NODE="astro-ats-033-lab-010-01-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-lab-010-01-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

node('systemctl','disable','--now','training-extra.service')
```

Apply the scoped correction:

```sh
python3 disable-service.py
kubectl apply -f configmap-host-review.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl get --raw=/readyz
```

Remove a seeded extra service from active and enabled node services while preserving Kubernetes. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-010-01-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
