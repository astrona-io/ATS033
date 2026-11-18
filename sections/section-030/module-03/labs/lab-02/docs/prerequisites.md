---
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona and a shell. The lab runs in a VM (virtual machine) with a one-node Kubernetes cluster built with kubeadm. Open a shell on the VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. The `curl` requests run on the node and reach the API server on `127.0.0.1:6443`.
