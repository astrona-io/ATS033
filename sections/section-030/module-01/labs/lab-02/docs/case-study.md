---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-01-02` has three pods. The pod `node-metrics-server` runs Python's web server in the network of the control-plane node on port 19091, bound to every address. The pod `shuttle` is a normal BusyBox pod on the control-plane node. The pod `scout` is a BusyBox pod that uses the network of the worker node.

The control-plane node has no host firewall rule for port 19091, so both test pods get the page. The task is to keep the listener and limit who can connect to it with `iptables` on the node.
