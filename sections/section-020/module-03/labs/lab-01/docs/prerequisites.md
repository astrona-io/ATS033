---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Prerequisites

Use astrona, kubectl, Python 3 and a shell. This environment needs no access to the nodes.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-01" || exit 1
```
