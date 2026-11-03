---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Remove Host Access From A Workload

Rewrite a Deployment that shares the host namespaces, mounts a host directory and runs privileged, then enforce the baseline Pod Security Standard on its namespace.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
