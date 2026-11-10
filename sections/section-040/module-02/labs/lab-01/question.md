---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The `shuttle` pod in `starfleet-033-040-02-01` carries cargo files, and the operations team wants a workload that can create and read files but can never delete them. The node of this cluster has no custom seccomp profile yet.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Write a seccomp profile `block-delete.json` with `defaultAction` `SCMP_ACT_ALLOW` and one rule that returns `SCMP_ACT_ERRNO` for the syscalls `unlink`, `unlinkat` and `rmdir`.
2. Place it on the node at `/var/lib/kubelet/seccomp/profiles/block-delete.json`. The node is the container `astro-ats-033-lab-040-02-01-control-plane`, and `podman cp` copies a file into it.
3. Create the pod `no-delete` in `starfleet-033-040-02-01` with `restartPolicy: Never`, `seccompProfile` type `Localhost` and `localhostProfile` `profiles/block-delete.json`, and one container `shell` that runs `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`.
4. Confirm that writing a file works and that deleting it with `rm` fails with `Operation not permitted`.

## Constraints

- Keep the sleeping process running.
- Do not use `Unconfined`, and do not change the `shuttle` pod.

## How the answer is checked

The grader runs two checks: `no-delete` runs with the `Localhost` profile `profiles/block-delete.json`, `/proc/1/status` reports `Seccomp: 2` and writing a file works; and `rm` fails with `Operation not permitted` inside the pod.
