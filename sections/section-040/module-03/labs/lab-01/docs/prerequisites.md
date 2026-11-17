---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Prerequisites

Use a host shell with astrona, kubectl, Podman and Python 3. Podman reaches the nodes, because a kind node is a container on your machine.

This lab needs a host whose kernel has AppArmor enabled, for example an Ubuntu Linux machine. A kind node uses the kernel of the machine that runs Podman, so a Mac, Windows or Fedora host cannot run it. The start of the lab checks every node: `/sys/module/apparmor/parameters/enabled` must contain `Y`. If `apparmor_parser` is missing in a node, the start installs the `apparmor` package there with `apt-get`, which needs internet access, and it may mount `securityfs` and restart containerd and the kubelet. The start stops with a clear message when the host has no AppArmor.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.
