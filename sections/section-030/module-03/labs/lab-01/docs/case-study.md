---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The cluster has one control-plane node and one worker node. The kubelet on the worker node has `authentication.anonymous.enabled` set to `true` and `authorization.mode` set to `AlwaysAllow` in `/var/lib/kubelet/config.yaml`. The node is `Ready`.

A node was set up for debugging. Its kubelet accepts anonymous requests and allows every request it receives. Anyone who can reach port 10250 of that node can list its pods.
