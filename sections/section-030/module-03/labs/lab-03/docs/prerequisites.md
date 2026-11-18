---
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona and a shell. The lab runs in a VM (virtual machine) with a one-node Kubernetes cluster built with kubeadm. Open a shell on the VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-03-03`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.
