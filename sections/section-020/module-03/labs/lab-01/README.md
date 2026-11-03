---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Give A Workload Its Own ServiceAccount And Remove Its Tokens

Use a dedicated ServiceAccount without a mounted token and remove the unused token paths.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
