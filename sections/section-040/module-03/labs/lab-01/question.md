---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The `scout` Deployment in `starfleet-033-040-03-01` runs under the AppArmor profile `k8s-deny-etc-write`. The team tested the profile in complain mode and found that `scout` needs no write access under `/etc`. Now the profile must start blocking.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node `astro-ats-033-lab-040-03-01` is the control plane and also runs the pods, and its kernel has AppArmor enabled. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-03-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-040-03-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. AppArmor files and the kernel profile list belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the current mode of `k8s-deny-etc-write` on the node. The profile file is `/etc/apparmor.d/k8s-deny-etc-write`.
2. Load the same file in enforce mode.
3. Restart the `scout` Deployment and confirm that `touch /etc/scout-check` inside the new pod fails.

## Constraints

- Do not change the rules in the profile file.
- Keep the `Localhost` AppArmor profile `k8s-deny-etc-write` on `scout`, and keep its image, command and one replica.

## How the answer is checked

The grader first checks that `scout` keeps its container, image, command and one replica, that the rollout is complete with exactly one pod, and that the pod uses the `Localhost` AppArmor profile `k8s-deny-etc-write`. Then it checks two outcomes. First, `/sys/kernel/security/apparmor/profiles` on the node lists `k8s-deny-etc-write (enforce)`. Second, `/proc/1/attr/current` in the `scout` pod reads `k8s-deny-etc-write (enforce)`, and `touch /etc/scout-check` fails with `Permission denied`.
