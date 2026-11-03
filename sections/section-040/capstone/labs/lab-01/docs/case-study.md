---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The Deployment `cargo` in `starfleet` runs as root, privileged, with escalation allowed and no seccomp profile. The security team prepared the seccomp profile `profiles/cargo-guard.json` on the node. It blocks the creation of symbolic and hard links, which attackers use to point a trusted path at another file.

Rewrite Deployment `cargo` in `starfleet` and keep its name, selector, image, command and one replica. Its pod must run as user and group 1000 with `runAsNonRoot: true`, `fsGroup: 1000` and the `Localhost` seccomp profile `profiles/cargo-guard.json`. Its container `cargo` must set `privileged: false`, `allowPrivilegeEscalation: false` and `readOnlyRootFilesystem: true`, and drop `ALL` capabilities without adding any back. An `emptyDir` volume `scratch` must be mounted at `/scratch`. In the running pod, `Seccomp` must be `2`, `NoNewPrivs` must be `1` and `CapBnd` must be all zeros. Writing in `/scratch` must work, writing `/root-file` must fail, and `ln -s` must fail with `Operation not permitted`. Do not use `Unconfined`. The Deployment rollout must be complete.
