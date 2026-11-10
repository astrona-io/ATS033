---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Disable An Unneeded Node Service

Remove a seeded extra service from active and enabled node services while preserving Kubernetes.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Static validation is not live evidence. Runtime verification remains pending.
