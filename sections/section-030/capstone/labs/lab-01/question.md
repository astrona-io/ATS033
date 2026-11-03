---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Reduce The External Exposure Of A Cluster

A security review of the cluster found three exposures: a node-local service on every interface, a Service that publishes the application on every node, and a kubelet that answers anonymous callers. Close all three without breaking the application.

## Starting state

The `starfleet` namespace runs the `probe` Deployment with two replicas and the `probe` Service of type `ClusterIP`. The pod `node-local-server` runs with `hostNetwork: true` on the control-plane node and listens on all interfaces at port 19090. The Services `probe-debug` (node port 30080) and `probe-public` (node port 30081) are of type `NodePort`. The kubelet on the worker node accepts anonymous requests and uses authorization mode `AlwaysAllow`. The `shuttle` pod in `starfleet` and the `drifter` pod in `outpost` run BusyBox.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-capstone-01" || exit 1
node_name="astro-ats-033-lab-030-capstone-01-control-plane"
worker_name="astro-ats-033-lab-030-capstone-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

1. Recreate the pod `node-local-server` in `starfleet` so that it listens on `127.0.0.1:19090` only (add `--bind 127.0.0.1` to the server command). Keep `hostNetwork: true` and the placement on the control-plane node. A request from the `shuttle` pod to the InternalIP of the control-plane node on port 19090 must fail with `Connection refused`.
2. Make `probe-debug` a `ClusterIP` Service with no node port. It must still work at `http://probe-debug.starfleet/` from the `shuttle` pod. A request from the `drifter` pod to the control-plane node on port 30080 must fail.
3. Keep `probe-public` of type `NodePort` on node port 30081 and set its `externalTrafficPolicy` to `Local`.
4. On the worker node, set `authentication.anonymous.enabled` to `false` and `authorization.mode` to `Webhook` in `/var/lib/kubelet/config.yaml`, and restart the kubelet. The worker node must be `Ready`.

Do not change the `probe` Deployment or the `probe` Service.

## Verify The Result

The grader checks the resource fields and live requests. Wait for the changes to settle, then repeat your own test requests before you submit.
