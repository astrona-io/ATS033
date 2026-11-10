---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Close An Accidental NodePort And Keep One Local

The `probe` application was published for a debugging session and the Service was never removed. Two Services expose the application on every node of the cluster. One of them has no reason to exist outside the cluster.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Static validation is not live evidence. Runtime verification remains pending.
