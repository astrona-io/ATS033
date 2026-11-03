---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Reduce The External Exposure Of A Cluster

A security review of the cluster found three exposures: a node-local service on every interface, a Service that publishes the application on every node, and a kubelet that answers anonymous callers. Close all three without breaking the application.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
