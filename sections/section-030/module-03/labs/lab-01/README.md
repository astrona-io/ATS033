---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Close The Kubelet API To Anonymous Callers

A node was set up for debugging. Its kubelet accepts anonymous requests and allows every request it receives. Anyone who can reach port 10250 of that node can list its pods.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
