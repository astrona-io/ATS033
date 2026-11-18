---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Dedicate A Worker Node To One Workload Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-03" || exit 1
worker_name="astro-ats-033-lab-010-03-03-worker"
```

## Look at the starting placement

The scheduler is the control-plane component that picks a node for each new pod. With no placement rules, it may use any worker node:

```sh
kubectl get nodes
kubectl -n starfleet-033-010-03-03 get pods -l app=ledger -o wide
```

```text
NAME                                        STATUS   ROLES           AGE   VERSION
astro-ats-033-lab-010-03-03-control-plane   Ready    control-plane   29s   v1.35.0
astro-ats-033-lab-010-03-03-worker          Ready    <none>          18s   v1.35.0
astro-ats-033-lab-010-03-03-worker2         Ready    <none>          18s   v1.35.0
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE                                  NOMINATED NODE   READINESS GATES
ledger-86965d785-khlc4   1/1     Running   0          7s    10.244.1.3   astro-ats-033-lab-010-03-03-worker2   <none>           <none>
ledger-86965d785-vds6v   1/1     Running   0          7s    10.244.1.2   astro-ats-033-lab-010-03-03-worker2   <none>           <none>
```

In this run, both `ledger` pods landed on `worker2`. In your run they may be on either worker.

## Label the worker and move ledger

A dedicated node needs two parts. The label with a `nodeSelector` sends the `ledger` pods to the node. The taint keeps every other pod away. Add the label first. The prefix `node-restriction.kubernetes.io/` matters: the NodeRestriction admission plugin stops a kubelet from setting labels with this prefix on its own node, so a compromised node cannot label itself to attract `ledger` pods.

```sh
kubectl label node "$worker_name" node-restriction.kubernetes.io/dedicated=ledger
kubectl get nodes -L node-restriction.kubernetes.io/dedicated
```

```text
node/astro-ats-033-lab-010-03-03-worker labeled
NAME                                        STATUS   ROLES           AGE   VERSION   DEDICATED
astro-ats-033-lab-010-03-03-control-plane   Ready    control-plane   35s   v1.35.0   
astro-ats-033-lab-010-03-03-worker          Ready    <none>          24s   v1.35.0   ledger
astro-ats-033-lab-010-03-03-worker2         Ready    <none>          24s   v1.35.0   
```

The `DEDICATED` column shows the label value. Next, give the `ledger` pod template the `nodeSelector` for the label and a toleration for the taint you add afterwards. Save this as `deployment-ledger.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger
  namespace: starfleet-033-010-03-03
spec:
  replicas: 2
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
```

Apply it:

```sh
kubectl apply -f deployment-ledger.yaml
```

Then check the result:

```sh
kubectl -n starfleet-033-010-03-03 rollout status deployment/ledger --timeout=120s
kubectl -n starfleet-033-010-03-03 get pods -l app=ledger -o wide
```

```text
Waiting for deployment "ledger" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "ledger" rollout to finish: 1 old replicas are pending termination...
deployment "ledger" successfully rolled out
NAME                      READY   STATUS        RESTARTS   AGE   IP           NODE                                  NOMINATED NODE   READINESS GATES
ledger-8668955685-44n9z   1/1     Running       0          3s    10.244.2.2   astro-ats-033-lab-010-03-03-worker    <none>           <none>
ledger-8668955685-6cfgm   1/1     Running       0          1s    10.244.2.3   astro-ats-033-lab-010-03-03-worker    <none>           <none>
ledger-86965d785-khlc4    1/1     Terminating   0          16s   10.244.1.3   astro-ats-033-lab-010-03-03-worker2   <none>           <none>
ledger-86965d785-vds6v    1/1     Terminating   0          16s   10.244.1.2   astro-ats-033-lab-010-03-03-worker2   <none>           <none>
```

The output is shortened: `rollout status` repeated each waiting line two or three times. Both new pods run on `astro-ats-033-lab-010-03-03-worker`, and the old pods on `worker2` are terminating.

## Taint the worker

Add the taint last, after the `ledger` pods run on the node. With the effect `NoSchedule`, the scheduler places no new pod on the node unless the pod has a matching toleration:

```sh
kubectl taint nodes "$worker_name" dedicated=ledger:NoSchedule
kubectl describe node "$worker_name" | grep -A1 Taints
```

```text
node/astro-ats-033-lab-010-03-03-worker tainted
Taints:             dedicated=ledger:NoSchedule
Unschedulable:      false
```

## Prove that other pods stay away

A test pod shows whether the taint works. This pod asks for the worker by its host name but has no toleration. Save this as `pod-visitor.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: visitor
  namespace: starfleet-033-010-03-03
spec:
  nodeSelector:
    kubernetes.io/hostname: astro-ats-033-lab-010-03-03-worker
  containers:
  - name: visitor
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-visitor.yaml
```

Then check the result. The events of the pod come from the scheduler:

```sh
kubectl -n starfleet-033-010-03-03 get pod visitor -o wide
kubectl -n starfleet-033-010-03-03 get events --field-selector involvedObject.name=visitor -o custom-columns=REASON:.reason,MESSAGE:.message
```

```text
NAME      READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE   READINESS GATES
visitor   0/1     Pending   0          6s    <none>   <none>   <none>           <none>
REASON             MESSAGE
FailedScheduling   0/3 nodes are available: 1 node(s) didn't match Pod's node affinity/selector, 2 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

The pod stays `Pending`. `worker2` does not match the `nodeSelector`, and the two other nodes have taints the pod does not tolerate: the control-plane node has its own taint, and the worker has `dedicated=ledger:NoSchedule`. Delete the test pod:

```sh
kubectl -n starfleet-033-010-03-03 delete pod visitor
```

```text
pod "visitor" deleted from starfleet-033-010-03-03 namespace
```

## Common pitfalls

> [!WARNING]
> - **Tainting before the rollout.** `NoSchedule` affects new pods. If the toleration is not in the template yet, the replacement `ledger` pods cannot use the node.
> - **A toleration without a `nodeSelector`.** The toleration allows the node but does not send the pod there. The pods may still run on `worker2`.
> - **A typo in the taint value or effect.** The toleration must match the key, the value and the effect, or the pods stay `Pending`.
> - **Using `NoExecute` by accident.** It also evicts running pods that do not tolerate the taint, including system pods on that node.
