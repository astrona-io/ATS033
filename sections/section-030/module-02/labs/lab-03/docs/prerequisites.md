---
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona, kubectl and a shell. Every step uses the Kubernetes API, so no node command is needed.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-03" || exit 1
node_name="astro-ats-033-lab-030-02-03-control-plane"
worker_name="astro-ats-033-lab-030-02-03-worker"
```

Keep this connection selected.
