---
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona, kubectl, Podman and a shell. Node commands run inside the node containers of this environment, not on the physical host. The node image ships `iptables`, the Linux command that manages packet filter rules.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-02" || exit 1
node_name="astro-ats-033-lab-030-01-02-control-plane"
worker_name="astro-ats-033-lab-030-01-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.
