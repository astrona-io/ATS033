---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Summary

AppArmor is a Linux security module that applies mandatory access control by name. A profile lists the files, capabilities and network operations that a program may use, and everything else is denied, even for root. The kernel enforces the profile. Kubernetes and the container runtime only tell the kernel which profile a container runs under.

A profile runs in enforce mode, where violations are blocked and logged, or in complain mode, where they are only logged. The usual way to write a profile is to start in complain mode, read the log, add rules and then enforce. The tool `apparmor_parser` loads or replaces a profile in the kernel, and `aa-status` and the file `/sys/kernel/security/apparmor/profiles` list the loaded profiles. A profile exists in the kernel of one node, so it must be loaded on every node that can run the pod, and again after a restart.

A pod selects a profile with `appArmorProfile`, at pod level or container level, with the types `RuntimeDefault`, `Localhost` and `Unconfined`. For `Localhost`, the value is the profile name written inside the file. The kubelet checks that the node supports AppArmor and that the profile is loaded, and it does not start the container when a check fails. The file `/proc/1/attr/current` inside the container shows the profile and mode that apply. The annotation form is deprecated.

Linux capabilities divide the power of root into units. A container receives a default set, and the fields `drop` and `add` change it. The safe pattern is to drop `ALL` and add back only the capability that a workload needs. The masks `CapBnd` and `CapEff` in `/proc/1/status` show the result, and for a non-root process `CapBnd` is the one to read.

The field `allowPrivilegeEscalation: false` sets `no_new_privs`, so a program cannot gain more rights than its parent. The setting `privileged: true` gives a container all capabilities and the devices of the node and removes the default profiles, so hardening starts by setting `privileged: false`. The Pod Security Standards require it at both the `baseline` and the `restricted` level.

Key facts:

- `NoNewPrivs: 1` follows from `allowPrivilegeEscalation: false`.
- A mask of zeros means no capabilities remain.
- Bit 10 is `NET_BIND_SERVICE`, which reads `0000000000000400` when it is the only capability.
- `deny` rules in an AppArmor profile win over allow rules.
- A node without AppArmor in its kernel cannot run a pod that needs an AppArmor profile.

<!-- astrona:playground:destroy -->
