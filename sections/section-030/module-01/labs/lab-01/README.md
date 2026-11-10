---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Bind A Host-Network Service To Loopback

Keep a node-local management-style service reachable locally while closing its node-address listener.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Static validation is not live evidence. Runtime verification remains pending.
