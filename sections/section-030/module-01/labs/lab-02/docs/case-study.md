---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The cluster has one node, which is the control plane and also runs the pods. The namespace `starfleet-033-030-01-02` has two pods. The pod `node-metrics-server` runs Python's web server in the network of the node on port 19091, bound to every address. The pod `shuttle` is a normal BusyBox pod with its own pod address, and it is the test client.

`ufw` is installed on the node but not active, so `shuttle` gets the page. Its default policies allow incoming and routed traffic. The task is to keep the listener and block port 19091 with a `ufw` rule on the node.
