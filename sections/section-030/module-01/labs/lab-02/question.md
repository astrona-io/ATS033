---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A metrics agent on the control-plane node must stay reachable for the worker node only. The pod `node-metrics-server` in the namespace `starfleet-033-030-01-02` runs Python's web server on port 19091 in the network of the control-plane node (`hostNetwork: true`). Right now every pod and every node can reach it. Two test pods sit in the same namespace. `shuttle` is a normal pod on the control-plane node. `scout` uses the network of the worker node, so its requests come from the worker's InternalIP.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-02" || exit 1
node_name="astro-ats-033-lab-030-01-02-control-plane"
worker_name="astro-ats-033-lab-030-01-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the control-plane node, add `iptables` rules to the `INPUT` chain that accept TCP traffic to port 19091 from the worker node's InternalIP and drop all other TCP traffic to port 19091.
2. Confirm that a request from `shuttle` to the control-plane node's InternalIP on port 19091 times out.
3. Confirm that a request from `scout` to the same address and port still returns the page.

## Constraints

- Keep `node-metrics-server` running and listening on port 19091. Do not change its bind address.
- Change only rules for port 19091. Do not change the default policy of the `INPUT` chain or the rules that Kubernetes created.
- The rules do not need to survive a node restart.

## How the answer is checked

The grader sends a request from `shuttle` to the control-plane node's InternalIP on port 19091 and expects a timeout. It then sends the same request from `scout` and expects the page with the text `Directory listing for /`. The check also needs `ss` on the control-plane node to show a listener on port 19091 and all three pods to be `Ready` on their nodes.

Hint: `iptables` reads a chain from the top. Rules that you append go to the end of the chain, so add the accept rule before the drop rule.
