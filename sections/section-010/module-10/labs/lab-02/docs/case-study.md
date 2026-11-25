---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. During an old outage, somebody installed a debugging package on the node. The package runs a systemd service that serves the node's log directory over HTTP on the loopback address, port 7070. The package also installed a configuration file under `/etc`. No other package depends on it, and Kubernetes does not use it.
