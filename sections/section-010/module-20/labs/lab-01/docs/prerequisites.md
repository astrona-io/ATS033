---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Prerequisites

Use `astrona` and a terminal. Every command runs in a shell on the lab VM, not on your own computer.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-02-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-02-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.
