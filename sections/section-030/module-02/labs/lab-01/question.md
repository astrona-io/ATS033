---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Close An Accidental NodePort And Keep One Local

The `probe` application was published for a debugging session and the Service was never removed. Two Services expose the application on every node of the cluster. One of them has no reason to exist outside the cluster.

## Starting state

The `starfleet` namespace runs the `probe` Deployment with two replicas and the `probe` Service of type `ClusterIP`. Two more Services select the same pods. `probe-debug` is of type `NodePort` on node port 30080. `probe-public` is of type `NodePort` on node port 30081. The `shuttle` pod in `starfleet` and the `drifter` pod in `outpost` run BusyBox.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-01" || exit 1
node_name="astro-ats-033-lab-030-02-01-control-plane"
worker_name="astro-ats-033-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

1. The Service `probe-debug` in `starfleet` must be of type `ClusterIP` and must keep no node port. It must still select the `probe` pods and forward port 80 to the container port named `http`, so `http://probe-debug.starfleet/` still works from the `shuttle` pod.
2. The Service `probe-public` must stay of type `NodePort` on node port 30081, with `externalTrafficPolicy` set to `Local`.
3. A request from the `drifter` pod to the InternalIP of the control-plane node on port 30080 must fail.

Do not delete or change the `probe` Deployment or the `probe` Service.

## Verify The Result

The grader checks the resource fields and live requests. Wait for the changes to settle, then repeat your own test requests before you submit.
