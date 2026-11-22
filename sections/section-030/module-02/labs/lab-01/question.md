---
exam_objectives:
- Minimize external access to the network
---
# Close An Accidental NodePort

Allow about 6 minutes for the tasks.

Solve this question on: `terminal`

The `probe` application was published for a debugging session, and the Service was never closed. The namespace `starfleet-033-030-02-01` runs the Deployment `probe` with two replicas, the ClusterIP Service `probe` and the Service `probe-debug` of type `NodePort` on node port 30080. Both Services select the `probe` pods. The pod `shuttle` in `starfleet-033-030-02-01` and the pod `drifter` in `outpost-033-030-02-01` run BusyBox.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-01" || exit 1
node_name="astro-ats-033-lab-030-02-01-control-plane"
worker_name="astro-ats-033-lab-030-02-01-worker"
```

Keep this connection selected.

The time above does not count the cluster startup.

## Tasks

1. Change the Service `probe-debug` to type `ClusterIP` with no node port. It must still select the `probe` pods and forward port 80 to the container port named `http`.
2. Confirm that `shuttle` still gets `version=v1` from `http://probe-debug/`.
3. Confirm that requests from `drifter` to port 30080 on the InternalIP of each node fail.

## Constraints

- Do not delete or change the Deployment `probe` or the Service `probe`.
- Keep the name `probe-debug`. Do not delete the Service and create it under another name.

## How the answer is checked

The first check reads `probe-debug`, expects type `ClusterIP` and no `nodePort` field, and sends a request from `shuttle` to `http://probe-debug/` that must return `version=v1`. The second check sends requests from `drifter` to port 30080 on the InternalIP of the control-plane node and of the worker node. Both must fail with `Connection refused` or a timeout.
