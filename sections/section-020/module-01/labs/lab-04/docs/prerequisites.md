---
exam_objectives:
- Using least-privilege identity and access management
---
# Prerequisites

Use `astrona` and a shell. The lab runs in a virtual machine (VM), and the VM is the only node of a one-node Kubernetes cluster. You work inside that VM, not on your own machine.

Open a shell on the VM and confirm the cluster:

```sh
astrona ssh astro-ats-033-lab-020-01-04
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-020-01-04`. You are logged in as the `student` user, which has a kubeconfig file (the file that tells `kubectl` which cluster to use and which credentials to send). Audit rules, the audit log and sudoers files belong to `root`, so run the commands that read or change them with `sudo`.
