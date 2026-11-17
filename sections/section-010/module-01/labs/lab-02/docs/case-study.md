---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The cluster has one control-plane node and one worker node. During an old outage, somebody installed a debugging package on the control-plane node. The package runs a systemd service that serves the node's log directory over HTTP on the loopback address, port 7070. The package also installed a configuration file under `/etc`. No other package depends on it, and Kubernetes does not use it.
