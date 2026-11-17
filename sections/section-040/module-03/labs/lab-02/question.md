---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The pod `bridge` in `starfleet-033-040-03-02` has two containers. Only the `logger` container must run under the AppArmor profile `k8s-deny-tmp-write`. Someone set the profile for the whole pod, so the `console` container cannot write its log under `/tmp` and keeps restarting.

This lab runs only on a host whose kernel has AppArmor enabled, for example an Ubuntu Linux machine. On other hosts the start of the lab stops with a message that says so.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find out why the `console` container of `bridge` restarts.
2. Create `bridge` again with the pod-level AppArmor profile type `RuntimeDefault`, and give only the `logger` container the `Localhost` profile `k8s-deny-tmp-write`.
3. Confirm that `console` is ready and that a write under `/tmp` fails in `logger` only.

## Constraints

- The profile `k8s-deny-tmp-write` is already loaded on both nodes. Do not change or unload it.
- Keep the pod name, the restart policy, both containers and their images and commands.

## How the answer is checked

The grader first checks that `bridge` keeps its containers, images, commands and restart policy, is ready, has the pod-level profile `RuntimeDefault`, and that `console` uses `RuntimeDefault` and `logger` uses `Localhost` `k8s-deny-tmp-write`. Then it checks two outcomes. First, `/proc/1/attr/current` in `console` shows a profile in enforce mode that is not `k8s-deny-tmp-write`, and `touch /tmp/console-check` works. Second, `/proc/1/attr/current` in `logger` reads `k8s-deny-tmp-write (enforce)`, and `touch /tmp/logger-check` fails with `Permission denied`.
