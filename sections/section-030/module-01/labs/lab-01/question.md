---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A node-local, management-style HTTP server must run on the control-plane node and be reachable only from that node itself. The namespace `starfleet-033-030-01-01` runs two healthy `probe` replicas, an internal Service and the client pods `shuttle` and `drifter`. The server does not exist yet.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-01" || exit 1
node_name="astro-ats-033-lab-030-01-01-control-plane"
worker_name="astro-ats-033-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the pod `node-local-server` in `starfleet-033-030-01-01` on the control-plane node's network: `hostNetwork: true` with `dnsPolicy: ClusterFirstWithHostNet`, a `nodeSelector` on the control-plane node's `kubernetes.io/hostname` and a toleration for the `node-role.kubernetes.io/control-plane` taint. Use `restartPolicy: Never` and one container `web` with the image `docker.io/library/python:3.13-alpine` and the command `python -m http.server 19090 --bind 127.0.0.1`.
2. Confirm that a request from the server container to `http://127.0.0.1:19090/` succeeds.
3. Confirm that a request from the `shuttle` pod to the node InternalIP on port 19090 fails with `Connection refused`.

## Constraints

- Listen on loopback only. This practices listener scope, not a host firewall implementation.
- Keep the node service and the cluster available.
- Preserve the namespace, the workload names and every unrelated component.

## How the answer is checked

The grader runs two checks: `node-local-server` is running on the control-plane node with the host network and answers on loopback with status 200; and its command binds `127.0.0.1`, so a request from `shuttle` to the node InternalIP on port 19090 is refused.

Hint: `kubectl get node -o wide` shows each node's InternalIP.
