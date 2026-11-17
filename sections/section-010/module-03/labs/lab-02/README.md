---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Enforce The Baseline Pod Security Standard

The setup script applies the `outpost-033-010-03-02` namespace without Pod Security labels and the `tracker` Deployment with `hostPID: true`, and waits for the rollout. The learner removes `hostPID` and labels the namespace `pod-security.kubernetes.io/enforce=baseline`.

Two outcomes are graded. `baseline-enforced` needs the label and sends a privileged pod with `kubectl run --dry-run=server`: the command must fail with `PodSecurity` in its error. `tracker-without-host-access` needs a template without host namespace fields or a privileged container, the original image, a complete rollout and no running `tracker` pod with a host namespace. Both orders (label first or fix first) pass, because the fixed template is compliant.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed with 2/2 points, and `verify-start.sh` failed both outcomes on the starting state. The commands and output in `solution.md` come from a manual run of the same environment.
