---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-02-01` runs the Deployment `probe` with two replicas. The ClusterIP Service `probe` and the NodePort Service `probe-debug` (node port 30080) both select its pods. Each `probe` pod answers HTTP requests on port 8080 with a line such as `version=v1 host=<pod name>`.

The client pod `shuttle` runs in `starfleet-033-030-02-01`, and the client pod `drifter` runs in `outpost-033-030-02-01`. Because `probe-debug` is a NodePort Service, kube-proxy opens port 30080 on every node, and any client that reaches a node can reach `probe`.
