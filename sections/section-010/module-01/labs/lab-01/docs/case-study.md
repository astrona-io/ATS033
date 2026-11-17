---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The cluster has one control-plane node and one worker node. An old image build left a systemd service on the control-plane node. The service is enabled, runs now and serves files over HTTP on TCP port 8099 on every address of the node. The service restarts its program when the program stops. Kubernetes does not use the service, and no other unit depends on it.
