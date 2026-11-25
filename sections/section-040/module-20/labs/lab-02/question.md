---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Block File Deletion With A Localhost seccomp Profile

Allow about 10 minutes for the tasks.

Solve this question on: `terminal`

The operations team in `starfleet-033-040-02-02` needs a workload that can create and read cargo files but can never delete them. The node of this cluster has no custom seccomp profile yet.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Write a seccomp profile `block-delete.json` with `defaultAction` `SCMP_ACT_ALLOW` and one rule that returns `SCMP_ACT_ERRNO` for the system calls `unlink`, `unlinkat` and `rmdir`.
2. Place it on the node at `/var/lib/kubelet/seccomp/profiles/block-delete.json`. The node is the container `astro-ats-033-lab-040-02-02-control-plane`, and `podman cp` copies a file into it.
3. Create the pod `no-delete` in `starfleet-033-040-02-02` with `restartPolicy: Never` and one container `shell` that runs `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`. The pod must use the `Localhost` profile `profiles/block-delete.json`.
4. Confirm that writing a file works and that deleting it with `rm` fails with `Operation not permitted`.

## Constraints

- Keep the sleeping process running.
- Do not use `Unconfined` or `RuntimeDefault` for `no-delete`.

## How the answer is checked

The grader first checks that `no-delete` exists with the container, image, command and restart policy above, runs, and has the effective seccomp profile `Localhost` `profiles/block-delete.json`. Then it checks two outcomes. First, the file on the node has `defaultAction` `SCMP_ACT_ALLOW` and an `SCMP_ACT_ERRNO` rule for `unlink`, `unlinkat` and `rmdir`, `/proc/1/status` reports `Seccomp: 2`, and a write under `/tmp` works. Second, one command inside `no-delete` creates a file and removes it with `rm`, and the `rm` fails with `Operation not permitted`.
