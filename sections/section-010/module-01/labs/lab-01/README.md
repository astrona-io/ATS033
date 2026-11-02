---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Disable An Unneeded Node Service

Remove a seeded extra service from active and enabled node services while preserving Kubernetes.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
