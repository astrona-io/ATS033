---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Replace A Wildcard Role And cluster-admin Binding

Replace a wildcard Role and a cluster-admin binding with a narrow Role.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Static validation is not live evidence. Runtime verification remains pending.
