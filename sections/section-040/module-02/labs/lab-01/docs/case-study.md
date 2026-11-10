---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The `shuttle` pod in `starfleet-033-040-02-01` carries cargo files, and the operations team wants a workload that can create and read files but can never delete them. The node of this cluster has no custom seccomp profile yet.

Write a seccomp profile `block-delete.json` with `defaultAction` `SCMP_ACT_ALLOW` and one rule that returns `SCMP_ACT_ERRNO` for the syscalls `unlink`, `unlinkat` and `rmdir`. Place it on the node at `/var/lib/kubelet/seccomp/profiles/block-delete.json`. The node is the container `astro-ats-033-lab-040-02-01-control-plane`, and `podman cp` copies a file into it. Create Pod `no-delete` in `starfleet-033-040-02-01` that runs BusyBox with `seccompProfile` type `Localhost` and `localhostProfile` `profiles/block-delete.json`. Writing a file must work and deleting it with `rm` must fail with `Operation not permitted`. Keep the sleeping process running.
