---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The `starfleet-033-010-03-01` namespace runs the `beacon` Deployment with one replica. Its pod template sets `hostNetwork: true` and `hostPID: true`, runs the container with `privileged: true` and mounts the node directory `/var/log` through a `hostPath` volume named `host-log` at `/host-log`. The container runs `sleep 3600` from the image `docker.io/library/busybox:1.37.0` and needs only a writable directory for temporary files.
