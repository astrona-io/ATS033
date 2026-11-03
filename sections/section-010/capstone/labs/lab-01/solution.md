---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Harden A Node And Its Workloads Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-capstone-01" || exit 1
node_name="astro-ats-033-lab-010-capstone-01-control-plane"
worker_name="astro-ats-033-lab-010-capstone-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

Inspect the four faults before you change anything. The commands read the service state, the SSH files and accounts of the worker node, the host access fields of `beacon` and the node placement of `ledger`.

```sh
podman exec "$node_name" systemctl is-enabled training-extra.service
podman exec "$worker_name" sh -c 'cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config'
podman exec "$worker_name" getent passwd opsadmin olduser
kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.hostPID}{"\n"}'
kubectl -n starfleet get pods -l app=ledger -o wide
kubectl describe node "$worker_name"
```

The order of the changes matters. The `beacon` rollout and the `ledger` rollout both need a node that accepts new pods, so the taint comes after them. The namespace label comes after the `beacon` rollout, because `baseline` rejects the old template.

Repair all four faults. Change only the objects and node settings named here.

1. On the control-plane node, stop and disable `training-extra.service`.
2. On the worker node, make the effective SSH settings `PermitRootLogin no`, `PasswordAuthentication no` (the first value that sshd reads), `PubkeyAuthentication yes` and `AllowUsers opsadmin`. Give `olduser` the shell `/usr/sbin/nologin` and lock its password. Keep `opsadmin` unchanged.
3. Rewrite the `beacon` pod template: no host namespaces, an `emptyDir` volume named `scratch` mounted at `/scratch` instead of the `hostPath` volume, and a container with `privileged: false`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `runAsUser: 10001` and all capabilities dropped. Label the `starfleet` namespace `pod-security.kubernetes.io/enforce=baseline`.
4. Dedicate the worker node to `ledger`. Label the node `node-restriction.kubernetes.io/dedicated=ledger` and taint it `dedicated=ledger:NoSchedule`. Give the `ledger` pod template the matching `nodeSelector` and a toleration for the taint. The `ledger` pod must run on the worker node.
5. Create the ConfigMap `section-review` in the `starfleet` namespace with the data `node-service: disabled`, `ssh: key-only`, `workload: beacon` and `dedicated-node: ledger`.

The `kubelet` and `containerd` services must stay active on both nodes, the API readiness endpoint must answer, and the `probe` Deployment must keep two ready replicas. Order matters: a taint with the effect `NoSchedule` keeps new pods away from the node, so finish every rollout that needs a pod on the worker node before you add the taint.

Save this as `disable-service.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-lab-010-capstone-01"
NODE="astro-ats-033-lab-010-capstone-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-lab-010-capstone-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

node('systemctl','disable','--now','training-extra.service')
```

Save this as `harden-ssh.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-033-lab-010-capstone-01"
NODE="astro-ats-033-lab-010-capstone-01-worker"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-lab-010-capstone-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

node('sed','-i','s/^PermitRootLogin .*/PermitRootLogin no/','/etc/ssh/sshd_config')
node('sed','-i','s/^PasswordAuthentication .*/PasswordAuthentication no/','/etc/ssh/sshd_config.d/50-cloud-init.conf')
if 'AllowUsers' not in node('cat','/etc/ssh/sshd_config'):
    node('sh','-c',"printf 'AllowUsers opsadmin\\n' >> /etc/ssh/sshd_config")
node('usermod','--shell','/usr/sbin/nologin','--lock','olduser')
```

Save this as `deployment-beacon.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beacon
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: beacon
  template:
    metadata:
      labels:
        app: beacon
    spec:
      containers:
      - name: beacon
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 10001
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: scratch
          mountPath: /scratch
      volumes:
      - name: scratch
        emptyDir: {}
```

Save this as `deployment-ledger.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ledger
  template:
    metadata:
      labels:
        app: ledger
    spec:
      nodeSelector:
        node-restriction.kubernetes.io/dedicated: ledger
      tolerations:
      - key: dedicated
        operator: Equal
        value: ledger
        effect: NoSchedule
      containers:
      - name: ledger
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 10001
          capabilities:
            drop:
            - ALL
```

Save this as `configmap-section-review.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: section-review
  namespace: starfleet
data:
  node-service: disabled
  ssh: key-only
  workload: beacon
  dedicated-node: ledger
```

Apply the changes in this order. The label and the `ledger` rollout come before the taint:

```sh
python3 disable-service.py
python3 harden-ssh.py
kubectl apply -f deployment-beacon.yaml
kubectl -n starfleet rollout status deployment/beacon --timeout=120s
kubectl label node "$worker_name" node-restriction.kubernetes.io/dedicated=ledger --overwrite
kubectl apply -f deployment-ledger.yaml
kubectl -n starfleet rollout status deployment/ledger --timeout=120s
kubectl taint nodes "$worker_name" dedicated=ledger:NoSchedule --overwrite
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl apply -f configmap-section-review.yaml
```

## Verify The Result

Check each fault again with an observation, not with the command you ran.

```sh
podman exec "$node_name" systemctl is-active training-extra.service
podman exec "$worker_name" sh -c 'cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config'
podman exec "$worker_name" passwd -S olduser
kubectl -n starfleet get pods -o wide
kubectl get node "$worker_name" -o jsonpath='{.spec.taints}{"\n"}'
kubectl get --raw=/readyz
```

The service must be inactive, the first value of each SSH setting must be the required one, `olduser` must show the status letter `L`, the `ledger` pod must run on the worker node, the node must show the `dedicated` taint and the readiness endpoint must answer `ok`.

After you record your result, remove the independent lab with `astrona destroy ats-033-lab-010-capstone-01`.

## Common pitfalls

> [!WARNING]
> - Add the taint last. A `NoSchedule` taint blocks new pods that do not tolerate it, including the replacement pods of a rollout.
> - A toleration allows a pod on a tainted node. It does not send the pod there. The `nodeSelector` does that, so the pod template needs both.
> - Edit the SSH file that holds the first value of each setting. A correct later line does not override an earlier one.
> - Label the namespace after the `beacon` rollout, not before.
