---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The Deployment `relay` in `starfleet-033-040-03-01` was started with `privileged: true` and escalation allowed, as root, with the full set of capabilities. The only privileged operation it ever needs is listening on a port below 1024.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. In the pod template of `relay`, set `runAsNonRoot: true`, `runAsUser: 1000` and the `RuntimeDefault` seccomp profile.
2. In the container `relay`, set `privileged: false` and `allowPrivilegeEscalation: false`.
3. Drop `ALL` capabilities and add back only `NET_BIND_SERVICE`.
4. Wait for the rollout, then confirm that `/proc/1/status` in the running pod shows `CapBnd: 0000000000000400`, `NoNewPrivs: 1` and `Seccomp: 2`.

## Constraints

- Keep the Deployment name, selector, image, command and one replica.
- Do not use `Unconfined`.

## How the answer is checked

The grader runs four checks: the pod requires a non-root user and runs as user 1000; it runs with the `RuntimeDefault` seccomp filter; the container is not privileged and blocks escalation (`NoNewPrivs: 1`); and the container keeps only `NET_BIND_SERVICE` (`CapBnd: 0000000000000400`). Every check also needs exactly one running `relay` pod after a complete rollout.
