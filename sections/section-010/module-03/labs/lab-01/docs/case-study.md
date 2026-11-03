---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The `starfleet` namespace runs the `beacon` Deployment with one replica. Its pod template sets `hostNetwork: true` and `hostPID: true`, runs the container with `privileged: true` and mounts the node directory `/var/log` through a `hostPath` volume named `host-log`. The namespace has no Pod Security Admission label. The `probe` Deployment, the `probe` Service and the `shuttle` and `drifter` pods run normally.
