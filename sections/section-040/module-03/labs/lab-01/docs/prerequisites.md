---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Prerequisites

Use a shell on your own machine with `astrona` installed. The lab runs in a VM (virtual machine) with Ubuntu 24.04, a one-node Kubernetes cluster built with kubeadm, and a kernel with AppArmor enabled. The VM already has `kubectl`, `apparmor_parser`, `aa-status` and `aa-enforce`.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-03-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-040-03-01`. You are logged in as the `student` user. Run node commands, such as `apparmor_parser`, with `sudo`. They change only the lab VM, not your own computer.
