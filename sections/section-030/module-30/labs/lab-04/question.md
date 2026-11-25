---
exam_objectives:
- Minimize external access to the network
---
# Restrict The etcd Data Directory

Allow about 6 minutes for the tasks.

Solve this question on: `terminal`

A security scan of the control-plane node reports that the etcd data directory is readable by every user on the node. etcd stores every Kubernetes object in this directory, including all Secrets. The directory must be readable by its owner only, and etcd must keep running.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-04
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-03-04`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Find the etcd data directory from the `--data-dir` flag in the etcd static pod manifest on the node.
2. Set the mode of that directory to `700`. Keep the owner `root:root`.
3. Confirm that etcd still reports itself healthy and that the API server is ready.

## Constraints

- Do not move, copy or delete the data directory.
- Do not change the etcd manifest.

## How the answer is checked

The grader runs `stat` on `/var/lib/etcd` on the node and expects mode `700` with owner and group `root`. Guards check that etcd answers its `/health` endpoint with `"health":"true"` when called with the API server's etcd client certificate, and that `kubectl get --raw /readyz` returns `ok`.
