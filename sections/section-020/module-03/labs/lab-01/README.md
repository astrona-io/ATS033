---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Give A Workload Its Own ServiceAccount And Remove Its Tokens

Use a dedicated ServiceAccount without a mounted token and remove the unused token paths.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Static validation is not live evidence. Runtime verification remains pending.
