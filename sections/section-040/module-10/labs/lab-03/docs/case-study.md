---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-01-03` holds the Deployment `scout` with one replica. Its container runs `docker.io/library/busybox:1.37.0` with the command `while date > /tmp/heartbeat; do sleep 5; done`. A readiness probe runs `cat /tmp/heartbeat`, so the pod is ready only while the file exists.

The pod template has no security context. The busybox image starts as root, the container keeps the default Linux capabilities, and no seccomp profile is set. The namespace has no Pod Security labels yet. The `restricted` level requires `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, all capabilities dropped and a `RuntimeDefault` or `Localhost` seccomp profile.
