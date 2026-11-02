---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Run With A Restricted Security Context

Keep a non-root workload functional with a read-only root filesystem and a writable scratch volume. Use the isolated `starfleet` environment to verify the result.

## Objective

Keep a non-root workload functional with a read-only root filesystem and a writable scratch volume.

## Starting state

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.


## Required result

Create Pod `restricted-reader` running BusyBox as user and group 1000, with `runAsNonRoot: true`, RuntimeDefault seccomp and group-writable emptyDir `scratch` mounted at `/scratch`. Its container must disable privilege escalation, drop all capabilities and use a read-only root filesystem. Writing in scratch must work; writing `/root-file` must fail. Keep the sleeping process running.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.

Verify `/proc/1/status` reports `Seccomp: 2` and `NoNewPrivs: 1` in the running reader. This confirms an installed seccomp filter. AppArmor requires a separately available kernel implementation and profile; this exercise does not claim AppArmor coverage.
