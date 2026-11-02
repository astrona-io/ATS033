---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Bind A Host-Network Service To Loopback

Keep a node-local management-style service reachable locally while closing its node-address listener.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-01" || exit 1
node_name="astro-ats-033-lab-030-01-01-control-plane"
worker_name="astro-ats-033-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create node-local-server on the control-plane container network, listening on 127.0.0.1:19090 only. A request from that server container to loopback must succeed. A request from the ordinary shuttle Pod to the node InternalIP on port 19090 must fail specifically with Connection refused. Keep the private node service and cluster available. This practices listener scope, not a host firewall implementation.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
