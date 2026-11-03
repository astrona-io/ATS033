---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Summary

A seccomp profile narrows the system calls that a container process may make. The container runtime installs the filter just before the application starts, the kernel enforces it, and the process can never remove it. The kubelet does not filter calls. It finds the profile, passes it to the runtime and applies the node default when a pod chooses nothing.

Kubernetes offers three profile types. `RuntimeDefault` uses the profile of the runtime and suits almost every workload. `Localhost` uses a file on the node, named relative to `/var/lib/kubelet/seccomp`. `Unconfined` installs no filter and also describes a privileged container. A pod without a profile runs unfiltered unless the kubelet runs with `seccompDefault: true`. A container value overrides a pod value.

A profile is a JSON document with a `defaultAction`, an optional list of `architectures` and a list of `syscalls` rules. Each rule has syscall names and an action such as `SCMP_ACT_ALLOW`, `SCMP_ACT_ERRNO`, `SCMP_ACT_LOG` or `SCMP_ACT_KILL_PROCESS`. A deny list allows by default and blocks named calls. An allow list blocks by default and names what is needed, which is stronger and takes more work to get right. Variants of one operation, such as `rename`, `renameat` and `renameat2`, must all be named.

A profile file must exist on every node that can run the pod, and the process in the container proves the result: `Seccomp: 2` in its status file and a blocked call that returns `Operation not permitted` while the pod keeps running.

When a pod fails, the pod events explain a profile that cannot be loaded, such as a wrong name, a missing copy or invalid JSON. A container that starts and then meets a denied operation has a content problem. The way to find it is to read the applied profile, map the failing action to syscall names, and confirm with a log action or a trace. The fix allows the one call that is needed. Setting `Unconfined` removes the protection and is not a fix.

Key facts:

- `Seccomp: 0` means no filter and `Seccomp: 2` means a filter in `/proc/1/status`.
- `localhostProfile` is a relative path under the kubelet seccomp directory.
- `SCMP_ACT_ERRNO` returns an error and keeps the process alive.
- The `restricted` Pod Security level accepts only `RuntimeDefault` or `Localhost`.

<!-- astrona:playground:destroy -->
