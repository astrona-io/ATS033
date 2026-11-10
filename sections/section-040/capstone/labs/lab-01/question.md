---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

Combine a Localhost seccomp profile, dropped capabilities, blocked escalation and a read-only filesystem on one Deployment. Use the isolated `starfleet` environment to verify the result.

The Deployment `cargo` in `starfleet` runs as root, privileged, with escalation allowed and no seccomp profile. The security team prepared the seccomp profile `profiles/cargo-guard.json` on the node. It blocks the creation of symbolic and hard links, which attackers use to point a trusted path at another file.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-capstone-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 25 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Rewrite the pod template of the Deployment `cargo` in `starfleet`: run as user and group 1000 with `runAsNonRoot: true`, `fsGroup: 1000` and the `Localhost` seccomp profile `profiles/cargo-guard.json`.
2. Harden the container `cargo`: set `privileged: false`, `allowPrivilegeEscalation: false` and `readOnlyRootFilesystem: true`, and drop `ALL` capabilities without adding any back. Mount an `emptyDir` volume `scratch` at `/scratch`.
3. Wait for the rollout, then confirm in the running pod that `Seccomp` is `2`, `NoNewPrivs` is `1` and `CapBnd` is all zeros; that writing in `/scratch` works and writing `/root-file` fails; and that `ln -s` fails with `Operation not permitted`.

## Constraints

- Keep the Deployment name, selector, image, command and one replica.
- Do not use `Unconfined`. The Deployment rollout must be complete.
- Preserve every unrelated component.

## How the answer is checked

The grader checks the stated resource fields and live evidence from inside the running container. Wait for the controller to converge before submitting. Inspect actual results rather than relying on a sample transcript.
