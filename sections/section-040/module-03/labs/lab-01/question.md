---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The `scout` Deployment in `starfleet-033-040-03-01` runs under the AppArmor profile `k8s-deny-etc-write`. The team tested the profile in complain mode and found that `scout` needs no write access under `/etc`. Now the profile must start blocking.

This lab runs only on a host whose kernel has AppArmor enabled, for example an Ubuntu Linux machine. On other hosts the start of the lab stops with a message that says so.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the current mode of `k8s-deny-etc-write` on both nodes, `astro-ats-033-lab-040-03-01-control-plane` and `astro-ats-033-lab-040-03-01-worker`. The profile file is `/etc/apparmor.d/k8s-deny-etc-write` in each node.
2. Load the same file in enforce mode on both nodes.
3. Restart the `scout` Deployment and confirm that `touch /etc/scout-check` inside the new pod fails.

## Constraints

- Do not change the rules in the profile file.
- Keep the `Localhost` AppArmor profile `k8s-deny-etc-write` on `scout`, and keep its image, command and one replica.

## How the answer is checked

The grader first checks that `scout` keeps its container, image, command and one replica, that the rollout is complete with exactly one pod, and that the pod uses the `Localhost` AppArmor profile `k8s-deny-etc-write`. Then it checks two outcomes. First, `/sys/kernel/security/apparmor/profiles` on both nodes lists `k8s-deny-etc-write (enforce)`. Second, `/proc/1/attr/current` in the `scout` pod reads `k8s-deny-etc-write (enforce)`, and `touch /etc/scout-check` fails with `Permission denied`.
