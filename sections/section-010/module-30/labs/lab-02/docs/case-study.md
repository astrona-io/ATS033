---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The `outpost-033-010-03-02` namespace has no labels that start with `pod-security.kubernetes.io/`, so Pod Security Admission applies no standard to it. The `tracker` Deployment runs one replica of `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`. Its pod template sets `hostPID: true`.
