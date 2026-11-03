---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Prerequisites

Use astrona, kubectl and a shell. This task changes Kubernetes objects only.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-01" || exit 1
```

Keep this connection selected. Every script supplied with this task refuses a different context.
