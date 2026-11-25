---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Set An AppArmor Profile For One Container

Allow about 10 minutes for the tasks.

Solve this question on: `terminal`

The pod `bridge` in `starfleet-033-040-03-02` has two containers. Only the `logger` container must run under the AppArmor profile `k8s-deny-tmp-write`. Someone set the profile for the whole pod, so the `console` container cannot write its log under `/tmp` and keeps restarting.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node `astro-ats-033-lab-040-03-02` is the control plane and also runs the pods, and its kernel has AppArmor enabled. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-040-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. The kernel profile list belongs to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Find out why the `console` container of `bridge` restarts.
2. Create `bridge` again with the pod-level AppArmor profile type `RuntimeDefault`, and give only the `logger` container the `Localhost` profile `k8s-deny-tmp-write`.
3. Confirm that `console` is ready and that a write under `/tmp` fails in `logger` only.

## Constraints

- The profile `k8s-deny-tmp-write` is already loaded on the node. Do not change or unload it.
- Keep the pod name, the restart policy, both containers and their images and commands.

## How the answer is checked

The grader first checks that `bridge` keeps its containers, images, commands and restart policy, is ready, has the pod-level profile `RuntimeDefault`, and that `console` uses `RuntimeDefault` and `logger` uses `Localhost` `k8s-deny-tmp-write`. Then it checks two outcomes. First, `/proc/1/attr/current` in `console` shows a profile in enforce mode that is not `k8s-deny-tmp-write`, and `touch /tmp/console-check` works. Second, `/proc/1/attr/current` in `logger` reads `k8s-deny-tmp-write (enforce)`, and `touch /tmp/logger-check` fails with `Permission denied`.
