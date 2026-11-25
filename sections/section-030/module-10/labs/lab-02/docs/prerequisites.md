---
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona and a shell. The lab runs in a VM (virtual machine) with a one-node Kubernetes cluster built with kubeadm. The node has `ufw` (Uncomplicated Firewall), a front end that writes host firewall rules into the packet filter of the Linux kernel. Open a shell on the VM and check that `kubectl` uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-01-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Firewall commands need `sudo`. They change only the lab VM, not your own computer.
