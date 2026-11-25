---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-02-01` holds two Deployments that run `docker.io/library/busybox:1.37.0` with `sh -c "sleep 3600"`. `bridge` has two replicas and no security context. `scout` has one replica, and its container sets `privileged: true`.

The kubelet of this cluster does not set `seccompDefault`, so a pod without a seccomp profile runs `Unconfined`. A privileged container also runs without a seccomp filter.
