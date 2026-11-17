---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Prerequisites

Use `astrona`, `kubectl`, Podman and a shell. Each node of the cluster is a Podman container, so `podman exec <node> <command>` runs a command on a node. The commands in this lab change only the node containers of this environment, not your own machine.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-01" || exit 1
node_name="astro-ats-033-lab-010-02-01-control-plane"
worker_name="astro-ats-033-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.
