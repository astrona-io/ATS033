---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-02-02` exists and is empty. The node has no kubelet seccomp directory, so no `Localhost` profile can be used yet.

The new pod `no-delete` must keep creating and reading files under `/tmp`. Removing a file or a directory must fail inside the pod, whatever user runs the command, because the kernel rejects the system call before it checks file permissions.
