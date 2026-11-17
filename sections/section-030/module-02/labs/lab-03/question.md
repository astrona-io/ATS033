---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A review of the cluster found three ways into the workloads that nobody approved. The only approved entry from outside the cluster is the NodePort Service `probe-public` on node port 30081 in `starfleet-033-030-02-03`. Every other entry must close, and the Service `probe-legacy` must keep working inside the cluster.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-03" || exit 1
node_name="astro-ats-033-lab-030-02-03-control-plane"
worker_name="astro-ats-033-lab-030-02-03-worker"
```

Keep this connection selected.

Allow about 15 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find every Service in the cluster that sets `externalIPs` and remove the field. Keep the Service, its type `ClusterIP` and its port.
2. Find every Service other than `probe-public` that opens a node port and change it to type `ClusterIP`.
3. Find every pod outside the `kube-*` namespaces that uses the host network and delete it.

## Constraints

- Do not change, delete or recreate `probe-public`, the Deployment `probe` or the pod `shuttle`.
- Do not change anything in the `kube-system` namespace.
- Do not add a firewall rule or a NetworkPolicy.

## How the answer is checked

The grader lists all Services and expects none with `externalIPs`. It sends a request from `shuttle` to `http://probe-legacy/`, which must return `version=v1`, and one to `203.0.113.10`, which must fail. It expects `starfleet-033-030-02-03/probe-public` to be the only Service with a node port: port 30081 on the worker node must return `version=v1`, and port 30090 must not answer. Last, it expects no pod with `hostNetwork: true` outside the `kube-*` namespaces, and a request to port 18080 on the worker node must be refused.
