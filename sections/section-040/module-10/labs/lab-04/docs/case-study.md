---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-01-04` holds the Deployment `shuttle` with one replica. Its pod template sets a `Localhost` seccomp profile at the pod level, so the kubelet must find the profile file on the node before the container runtime can create the container.

The security team installed the approved profile at `/var/lib/kubelet/seccomp/profiles/shuttle-guard.json`. The profile allows every system call except the ones that change file permissions (`chmod`, `fchmod`, `fchmodat` and `fchmodat2`). The `shuttle` pod is stuck and never reaches the `Running` phase.
