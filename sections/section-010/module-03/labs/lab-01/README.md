---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Remove Host Access From A Workload

Rewrite a Deployment that shares the host namespaces, mounts a host directory and runs privileged, then enforce the baseline Pod Security Standard on its namespace.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Static validation is not live evidence. Runtime verification remains pending.
