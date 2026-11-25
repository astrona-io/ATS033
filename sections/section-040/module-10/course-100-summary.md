# Summary

Containers share the kernel of their node. So a flaw in a kernel feature that a process may call is a flaw for every container on that node. Kernel hardening narrows what each process can reach.

Seccomp (secure computing mode) filters system calls (syscalls). Child processes inherit the filter, and a process cannot remove it once it is installed. The filter decides only on the syscall and its numeric arguments. AppArmor is mandatory access control by name: a profile lists the files, capabilities and network operations that a program may use, and everything else is denied, even for root.

Kubernetes selects both in a securityContext. The field `seccompProfile` takes `RuntimeDefault`, `Localhost` or `Unconfined`. For `Localhost`, `localhostProfile` is a path relative to `/var/lib/kubelet/seccomp`. The field `appArmorProfile`, available since v1.30, takes the same three types, and its `localhostProfile` is the name inside the profile file. A container value overrides a pod value. Without a seccomp profile and without the kubelet setting `seccompDefault: true`, a pod runs without a filter.

A profile works only if the node provides it. A `Localhost` profile must exist on every node where the pod can run. AppArmor needs a kernel with the module enabled and a runtime that supports it. A `kind` playground node uses the kernel of the machine that runs Podman, so AppArmor may be unavailable there.

The restricted security context combines the identity and filesystem settings with the kernel profiles: a non-root user, `allowPrivilegeEscalation: false`, all capabilities dropped, a read-only root filesystem with a writable volume, `fsGroup` for the volume and `RuntimeDefault` seccomp. Inside the container, the files `/proc/1/status` and `/proc/1/attr/current` show what is applied.

When a profile fails, look at where the failure happens. A pod that does not start has a delivery problem, and the pod events explain it. An application that starts and is then denied has a content problem, and the application log and the kernel log explain it. The fix is to allow the one call or path that is needed. Setting `Unconfined` removes the protection and is not a fix.

Key facts to remember:

- `Seccomp: 2` in `/proc/1/status` means a filter is installed. `0` means none.
- `NoNewPrivs: 1` follows from `allowPrivilegeEscalation: false`.
- The `baseline` standard rejects explicit `Unconfined` seccomp, and `restricted` requires `RuntimeDefault` or `Localhost`.
- The old AppArmor annotation is deprecated, so use the `appArmorProfile` field.
- Profiles do not survive a node replacement unless the node image or a boot service provides them.

<!-- astrona:playground:destroy -->
