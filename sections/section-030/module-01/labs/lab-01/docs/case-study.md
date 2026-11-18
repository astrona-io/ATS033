---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-01-01` has two pods. The cluster has one node, which is the control plane and also runs the pods. The pod `node-local-server` runs Python's web server in the network of the node, bound to `0.0.0.0:19090`. The pod `shuttle` runs BusyBox with its own pod address and is the test client.

The server answers on every address of the node, so any pod can reach it. The task is to narrow the listener to the loopback address of the node.
