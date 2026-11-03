---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Harden A Workload With seccomp, Capabilities And A Read-Only Filesystem

Combine a Localhost seccomp profile, dropped capabilities, blocked escalation and a read-only filesystem on one Deployment. Use the isolated `starfleet` environment to verify the result.

## Objective

Combine a Localhost seccomp profile, dropped capabilities, blocked escalation and a read-only filesystem on one Deployment.

## Starting state

The Deployment `cargo` in `starfleet` runs as root, privileged, with escalation allowed and no seccomp profile. The security team prepared the seccomp profile `profiles/cargo-guard.json` on the node. It blocks the creation of symbolic and hard links, which attackers use to point a trusted path at another file.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-capstone-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

Rewrite Deployment `cargo` in `starfleet` and keep its name, selector, image, command and one replica. Its pod must run as user and group 1000 with `runAsNonRoot: true`, `fsGroup: 1000` and the `Localhost` seccomp profile `profiles/cargo-guard.json`. Its container `cargo` must set `privileged: false`, `allowPrivilegeEscalation: false` and `readOnlyRootFilesystem: true`, and drop `ALL` capabilities without adding any back. An `emptyDir` volume `scratch` must be mounted at `/scratch`. In the running pod, `Seccomp` must be `2`, `NoNewPrivs` must be `1` and `CapBnd` must be all zeros. Writing in `/scratch` must work, writing `/root-file` must fail, and `ln -s` must fail with `Operation not permitted`. Do not use `Unconfined`. The Deployment rollout must be complete.

## Verify The Result

The grader checks the stated resource fields and live evidence from inside the running container. Wait for the controller to converge before submitting. Inspect actual results rather than relying on a sample transcript.
