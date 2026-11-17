---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

The public entry point of `probe` must answer only on nodes that run a `probe` pod. The namespace `starfleet-033-030-02-02` runs the Deployment `probe` with two replicas, and both pods run on the worker node. The Service `probe-public` exposes them as type `NodePort` on node port 30081 with `externalTrafficPolicy: Cluster`, so every node forwards the traffic, including the control-plane node. The client pod `drifter` runs on the worker node in `outpost-033-030-02-02`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-02" || exit 1
node_name="astro-ats-033-lab-030-02-02-control-plane"
worker_name="astro-ats-033-lab-030-02-02-worker"
```

Keep this connection selected.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Set `externalTrafficPolicy` of the Service `probe-public` to `Local`. Keep the type `NodePort` and node port 30081.
2. Confirm that a request from `drifter` to the worker node's InternalIP on port 30081 returns `version=v1`.
3. Confirm that a request from `drifter` to the control-plane node's InternalIP on port 30081 times out.

## Constraints

- Do not move, scale or change the `probe` pods or `drifter`.
- Do not add a firewall rule or a NetworkPolicy.

## How the answer is checked

The grader reads `probe-public` and expects type `NodePort`, node port 30081 and `externalTrafficPolicy: Local`. It then sends a request from `drifter` to port 30081 on the worker node, which must return `version=v1`, and to port 30081 on the control-plane node, which must time out. A guard checks that `drifter` and every `probe` pod still run on the worker node.
