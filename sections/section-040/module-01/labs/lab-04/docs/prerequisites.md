---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Prerequisites

Use a host shell with astrona, kubectl, Podman and Python 3. Podman reaches the node, because a kind node is a container on your machine.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-04" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.
