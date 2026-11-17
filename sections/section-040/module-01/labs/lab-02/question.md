---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The `scout` workload in `starfleet-033-040-01-02` must never write under `/tmp`, even as root. The cluster has two nodes, and no custom AppArmor profile is loaded yet.

This lab runs only on a host whose kernel has AppArmor enabled, for example an Ubuntu Linux machine. On other hosts the start of the lab stops with a message that says so.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Write an AppArmor profile named `k8s-deny-tmp-write` with the flag `attach_disconnected`. It must allow file, network and capability use and deny write access to every path under `/tmp`.
2. Load the profile in enforce mode on both nodes, `astro-ats-033-lab-040-01-02-control-plane` and `astro-ats-033-lab-040-01-02-worker`. Save it as `/etc/apparmor.d/k8s-deny-tmp-write` in each node and load it with `apparmor_parser`.
3. Create the pod `scout` in `starfleet-033-040-01-02` with `restartPolicy: Never` and one container `scout` that runs `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`. Select the profile with the `appArmorProfile` field, type `Localhost`.
4. Confirm that `touch /tmp/scout-check` inside `scout` fails.

## Constraints

- Use the `appArmorProfile` field, not the deprecated annotation.
- Do not load the profile in complain mode.

## How the answer is checked

The grader first checks that `scout` exists with the container, image, command and restart policy above, is running and ready, and has the effective AppArmor profile `Localhost` `k8s-deny-tmp-write`. Then it checks three outcomes. First, `/sys/kernel/security/apparmor/profiles` on both nodes lists `k8s-deny-tmp-write (enforce)`. Second, `/proc/1/attr/current` inside `scout` reads `k8s-deny-tmp-write (enforce)`. Third, `touch /tmp/scout-check` inside `scout` fails with `Permission denied`.
