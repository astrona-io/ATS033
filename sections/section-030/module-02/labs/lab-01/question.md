---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

The `probe` application was published for a debugging session and the Service was never removed. Two Services expose the application on every node of the cluster; one of them has no reason to exist outside the cluster. The `starfleet-033-030-02-01` namespace runs the `probe` Deployment with two replicas and the `probe` Service of type `ClusterIP`. `probe-debug` is of type `NodePort` on node port 30080, and `probe-public` is of type `NodePort` on node port 30081. Both select the `probe` pods. The `shuttle` pod in `starfleet-033-030-02-01` and the `drifter` pod in `outpost-033-030-02-01` run BusyBox.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-01" || exit 1
node_name="astro-ats-033-lab-030-02-01-control-plane"
worker_name="astro-ats-033-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Make the Service `probe-debug` of type `ClusterIP` with no node port. It must still select the `probe` pods and forward port 80 to the container port named `http`, so `http://probe-debug.starfleet-033-030-02-01/` still works from the `shuttle` pod.
2. Keep the Service `probe-public` of type `NodePort` on node port 30081 and set its `externalTrafficPolicy` to `Local`.
3. Confirm that a request from the `drifter` pod to the InternalIP of the control-plane node on port 30080 fails.

## Constraints

- Do not delete or change the `probe` Deployment or the `probe` Service.
- Preserve the namespaces, the workload names and every unrelated component.

## How the answer is checked

The grader runs two checks: `probe-debug` is a `ClusterIP` Service with no node port, still answers `shuttle`, and port 30080 on the control-plane node no longer answers `drifter`; and `probe-public` is a `NodePort` Service on node port 30081 with `externalTrafficPolicy: Local`. Wait for the changes to settle, then repeat your own test requests before you submit.
