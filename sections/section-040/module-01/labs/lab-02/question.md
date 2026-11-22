---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Load An AppArmor Profile And Attach It To A Pod

Allow about 12 minutes for the tasks.

Solve this question on: `terminal`

The `scout` workload in `starfleet-033-040-01-02` must never write under `/tmp`, even as root. No custom AppArmor profile is loaded yet.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node `astro-ats-033-lab-040-01-02` is the control plane and also runs the pods, and its kernel has AppArmor enabled. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-040-01-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. AppArmor files and the kernel profile list belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Write an AppArmor profile named `k8s-deny-tmp-write` with the flag `attach_disconnected`. It must allow file, network and capability use, allow the container runtime `runc` to send it signals (`signal (receive) peer=runc,`), and deny write access to every path under `/tmp`.
2. Save it as `/etc/apparmor.d/k8s-deny-tmp-write` on the node and load it in enforce mode with `apparmor_parser`.
3. Create the pod `scout` in `starfleet-033-040-01-02` with `restartPolicy: Never` and one container `scout` that runs `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`. Select the profile with the `appArmorProfile` field, type `Localhost`.
4. Confirm that `touch /tmp/scout-check` inside `scout` fails.

## Constraints

- Use the `appArmorProfile` field, not the deprecated annotation.
- Do not load the profile in complain mode.

## How the answer is checked

The grader first checks that `scout` exists with the container, image, command and restart policy above, is running and ready, and has the effective AppArmor profile `Localhost` `k8s-deny-tmp-write`. Then it checks three outcomes. First, `/sys/kernel/security/apparmor/profiles` on the node lists `k8s-deny-tmp-write (enforce)`. Second, `/proc/1/attr/current` inside `scout` reads `k8s-deny-tmp-write (enforce)`. Third, `touch /tmp/scout-check` inside `scout` fails with `Permission denied`.
