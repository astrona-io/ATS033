---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Replace A Wildcard Role And cluster-admin Binding

Replace a wildcard Role and a cluster-admin binding with a narrow Role.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
