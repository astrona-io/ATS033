---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A change to the control-plane node widened the listener of kube-scheduler. Port 10259 now answers on every address of the node, and the pod `shuttle` in `starfleet-033-030-03-01` can reach it through the node address. Only the node itself needs this port, for health checks and metrics.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-03-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Change the kube-scheduler static pod manifest on the node so that kube-scheduler listens on `127.0.0.1` only.
2. Confirm that kube-scheduler still answers `ok` on `https://127.0.0.1:10259/healthz` on the node.
3. Confirm that a request from `shuttle` to port 10259 on the node's InternalIP is refused.

## Constraints

- Change only the bind address. Keep every other flag of kube-scheduler.
- Do not add a firewall rule and do not stop kube-scheduler.

## How the answer is checked

The grader reads the command line of the running kube-scheduler process and expects `--bind-address=127.0.0.1`. It reads the listeners of the node with `ss` and expects port 10259 on `127.0.0.1` only, and it expects `ok` from the local health check. Then it sends a request from `shuttle` to port 10259 on the node's InternalIP, which must fail with `Connection refused`. A guard checks that the kube-scheduler pod is Ready.
