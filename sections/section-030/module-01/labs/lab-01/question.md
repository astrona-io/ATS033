---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A node agent was deployed for local health checks, and a security scan of the control-plane node found it listening on all interfaces. The pod `node-local-server` in the namespace `starfleet-033-030-01-01` runs Python's web server on port 19090 in the network of the control-plane node (`hostNetwork: true`). Its command binds the server to `0.0.0.0`, so the pod `shuttle` in the same namespace, which runs on the worker node, can reach it at the node address. Only processes on the control-plane node itself need this server.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-01" || exit 1
node_name="astro-ats-033-lab-030-01-01-control-plane"
worker_name="astro-ats-033-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the listener of port 19090 on the control-plane node and confirm that it accepts connections on every address.
2. Change `node-local-server` so that the web server listens on `127.0.0.1:19090` only. Keep the pod name, the namespace, the host network and the control-plane node.
3. Confirm that a request on the node's loopback address returns status 200, and that a request from `shuttle` to the node's InternalIP on port 19090 fails with `Connection refused`.

## Constraints

- Fix the listener itself. Do not add a firewall rule or a NetworkPolicy.
- Keep `shuttle` and every other component of the cluster as they are.

## How the answer is checked

The grader runs two checks. First, `ss` on the control-plane node shows port 19090 on `127.0.0.1` and on no other address. Second, a request from `shuttle` to the node's InternalIP on port 19090 gets `Connection refused`. Both checks also need `node-local-server` to be `Ready` on the control-plane node and a request to `http://127.0.0.1:19090/` on that node to return 200.

Hint: the command of a running container cannot change. Replace the pod.
