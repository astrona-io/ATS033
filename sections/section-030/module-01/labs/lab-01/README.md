---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Bind A Host-Network Service To Loopback

Keep a node-local management-style service reachable locally while closing its node-address listener.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
