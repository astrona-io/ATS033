---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-02-02` runs the Deployment `probe` with two replicas. A node affinity rule keeps both pods on the worker node. The Service `probe-public` is of type `NodePort` on node port 30081 with `externalTrafficPolicy: Cluster`. The client pod `drifter` runs on the worker node in `outpost-033-030-02-02`.

With the policy `Cluster`, kube-proxy on every node accepts traffic on port 30081 and forwards it to any `probe` pod, even when the pod runs on another node. The control-plane node therefore answers on port 30081, although no `probe` pod runs there.
