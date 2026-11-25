---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. An old image build left a systemd service on the node. The service is enabled, runs now and serves files over HTTP on TCP port 8099 on every address of the node. The service restarts its program when the program stops. Kubernetes does not use the service, and no other unit depends on it.
