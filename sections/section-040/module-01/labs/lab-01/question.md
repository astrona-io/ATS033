---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

A reader workload must run with the smallest set of rights that still lets it work: no root, no extra privileges and no writes outside one scratch directory. The namespace `starfleet-033-040-01-01` has healthy application and client fixtures. The pod does not exist yet.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the pod `restricted-reader` in `starfleet-033-040-01-01` with `restartPolicy: Never` and one container `reader` that runs `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`. At pod level, run as user and group 1000 with `runAsNonRoot: true`, `fsGroup: 1000` and the `RuntimeDefault` seccomp profile.
2. Harden the `reader` container: disable privilege escalation, drop all capabilities and use a read-only root filesystem.
3. Mount an `emptyDir` volume named `scratch` at `/scratch`. Writing in `/scratch` must work; writing `/root-file` must fail.
4. Confirm that `/proc/1/status` in the running container reports `Seccomp: 2` and `NoNewPrivs: 1`.

## Constraints

- Keep the sleeping process running.
- Complete the change without replacing unrelated resources.

## How the answer is checked

The grader runs four checks: the pod runs as user and group 1000 and requires a non-root user; it runs with the `RuntimeDefault` seccomp filter (`Seccomp: 2`); the container blocks escalation (`NoNewPrivs: 1`), drops all capabilities and cannot write `/root-file`; and the `scratch` volume is mounted and writable. `Seccomp: 2` confirms an installed seccomp filter. AppArmor requires a separately available kernel implementation and profile; this exercise does not claim AppArmor coverage.
