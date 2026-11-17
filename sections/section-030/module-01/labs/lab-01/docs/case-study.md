---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-01-01` has two pods. The pod `node-local-server` runs Python's web server in the network of the control-plane node, bound to `0.0.0.0:19090`. The pod `shuttle` runs BusyBox on the worker node and is the test client.

The server answers on every address of the control-plane node, so any pod can reach it. The task is to narrow the listener to the loopback address of the node.
