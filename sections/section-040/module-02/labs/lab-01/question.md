---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Block File Deletion With A Localhost seccomp Profile

Write a seccomp profile, place it on the node and run a pod that cannot delete files. Use the isolated `starfleet` environment to verify the result.

## Objective

Write a seccomp profile, place it on the node and run a pod that cannot delete files.

## Starting state

The `shuttle` pod in `starfleet` carries cargo files, and the operations team wants a workload that can create and read files but can never delete them. The node of this cluster has no custom seccomp profile yet.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

Write a seccomp profile `block-delete.json` with `defaultAction` `SCMP_ACT_ALLOW` and one rule that returns `SCMP_ACT_ERRNO` for the syscalls `unlink`, `unlinkat` and `rmdir`. Place it on the node at `/var/lib/kubelet/seccomp/profiles/block-delete.json`. The node is the container `astro-ats-033-lab-040-02-01-control-plane`, and `podman cp` copies a file into it. Create Pod `no-delete` in `starfleet` that runs BusyBox with `seccompProfile` type `Localhost` and `localhostProfile` `profiles/block-delete.json`. Writing a file must work and deleting it with `rm` must fail with `Operation not permitted`. Keep the sleeping process running.

## Verify The Result

The grader checks the stated resource fields and live evidence from inside the running container. Wait for the controller to converge before submitting. Inspect actual results rather than relying on a sample transcript.
