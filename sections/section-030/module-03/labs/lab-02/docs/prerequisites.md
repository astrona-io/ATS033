---
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona, kubectl, Podman and a shell. The `curl` requests run inside the control-plane node container of this lab with `podman exec`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-02" || exit 1
node_name="astro-ats-033-lab-030-03-02-control-plane"
worker_name="astro-ats-033-lab-030-03-02-worker"
```

Keep this connection selected.
