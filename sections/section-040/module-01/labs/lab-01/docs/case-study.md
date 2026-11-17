---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-01-01` exists and is empty. The security team wrote a seccomp profile for the `scout` workload and left it on the node at `/opt/course/seccomp/scout-guard.json`. The profile allows every system call except the ones that create a directory or a device file.

The kubelet loads a `Localhost` profile only from its seccomp directory, `/var/lib/kubelet/seccomp`. That directory does not exist on the node yet. The pod `scout` must run under the profile, keep writing files under `/tmp` and fail when it tries to create a directory.
