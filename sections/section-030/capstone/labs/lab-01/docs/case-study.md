---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The `starfleet` namespace runs the `probe` Deployment with two replicas and the `probe` Service of type `ClusterIP`. The pod `node-local-server` runs with `hostNetwork: true` on the control-plane node and listens on all interfaces at port 19090. The Services `probe-debug` (node port 30080) and `probe-public` (node port 30081) are of type `NodePort`. The kubelet on the worker node accepts anonymous requests and uses authorization mode `AlwaysAllow`. The `shuttle` pod in `starfleet` and the `drifter` pod in `outpost` run BusyBox.

A security review of the cluster found three exposures: a node-local service on every interface, a Service that publishes the application on every node, and a kubelet that answers anonymous callers. Close all three without breaking the application.
