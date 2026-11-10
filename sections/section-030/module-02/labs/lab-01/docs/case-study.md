---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The `starfleet-033-030-02-01` namespace runs the `probe` Deployment with two replicas and the `probe` Service of type `ClusterIP`. Two more Services select the same pods. `probe-debug` is of type `NodePort` on node port 30080. `probe-public` is of type `NodePort` on node port 30081. The `shuttle` pod in `starfleet-033-030-02-01` and the `drifter` pod in `outpost-033-030-02-01` run BusyBox.

The `probe` application was published for a debugging session and the Service was never removed. Two Services expose the application on every node of the cluster. One of them has no reason to exist outside the cluster.
