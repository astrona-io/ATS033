---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Summary

Containers share the kernel of their node, so a flaw in a kernel feature that a process may call is a flaw for every container on that node. Kernel hardening narrows what each process can reach. Seccomp filters system calls. It is inherited by child processes and cannot be removed once installed, and it decides on the syscall and its numbers only. AppArmor is mandatory access control by name: a profile lists the files, capabilities and network operations that a program may use, and everything else is denied, even for root.

Kubernetes selects both in a securityContext. The field `seccompProfile` takes `RuntimeDefault`, `Localhost` (with `localhostProfile` relative to `/var/lib/kubelet/seccomp`) or `Unconfined`. The field `appArmorProfile`, available since v1.30, takes the same three types, and `localhostProfile` is the name inside the profile file. A container value overrides a pod value. Without a seccomp profile and without the kubelet setting `seccompDefault: true`, a pod runs without a filter.

A profile works only if the node provides it. A `Localhost` profile must exist on every node where the pod can run, and AppArmor needs a kernel with the module enabled and a runtime that supports it. A `kind` playground node uses the kernel of the machine that runs Podman, so AppArmor may be unavailable there.

The restricted security context combines the identity and filesystem settings with the kernel profiles: non-root user, `allowPrivilegeEscalation: false`, all capabilities dropped, a read-only root filesystem with a writable volume, `fsGroup` for the volume and `RuntimeDefault` seccomp. The files `/proc/1/status` and `/proc/1/attr/current` show inside the container what is applied.

When a profile fails, a pod that does not start has a delivery problem that the pod events explain, and an application that starts and is denied has a content problem that the application log and the kernel log explain. The fix is to allow the one call or path that is needed. Setting `Unconfined` removes the protection and is not a fix.

Key facts:

- `Seccomp: 2` in `/proc/1/status` means a filter is installed. `0` means none.
- `NoNewPrivs: 1` follows from `allowPrivilegeEscalation: false`.
- The `baseline` standard rejects explicit `Unconfined` seccomp, and `restricted` requires `RuntimeDefault` or `Localhost`.
- The old AppArmor annotation is deprecated, so use the `appArmorProfile` field.
- Profiles do not survive a node replacement unless the node image or a boot service provides them.

<!-- astrona:playground:destroy -->
