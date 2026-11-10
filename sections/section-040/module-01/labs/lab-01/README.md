---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Run With A Restricted Security Context

Keep a non-root workload functional with a read-only root filesystem and a writable scratch volume. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.

Verify `/proc/1/status` reports `Seccomp: 2` and `NoNewPrivs: 1` in the running reader. This confirms an installed seccomp filter. AppArmor requires a separately available kernel implementation and profile; this exercise does not claim AppArmor coverage.
