---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Apply seccomp Profiles To Pods

A container shares the kernel of its node, and the kernel offers several hundred system calls. A system call (syscall) is a request that a process sends to the kernel, for example to open a file, create a directory or change a permission. Most applications need only a small part of them, but a pod that has no filter may call all of them. seccomp (secure computing mode) is the kernel feature that filters syscalls, and a seccomp profile is the file that tells the kernel which syscalls a process may make.

Keep one sentence in mind for this module: **a seccomp profile is a JSON document with a default action and a list of syscall rules, the kubelet reads it from a directory on the node, and a pod selects it with `securityContext.seccompProfile`.** You will compare the three profile types, write a profile that blocks one group of syscalls, copy it to the node, run a pod under it, and read the failures that a wrong or missing profile causes.

The module has three parts. **Profile Types, Locations And The Unconfined Risk** covers `RuntimeDefault`, `Localhost` and `Unconfined`, the directory `/var/lib/kubelet/seccomp` and what an unfiltered pod costs. **Write And Load A Localhost Profile** covers the JSON structure with `defaultAction` and `syscalls`, and loads a profile on a node. **Find Blocked Syscalls And Fix Failures** shows how to tell which syscall a profile blocked and how to repair a pod that cannot start.

## Learning objectives

After this module you can:

- Choose between `RuntimeDefault`, `Localhost` and `Unconfined` and explain the risk of `Unconfined`.
- Place a profile file under `/var/lib/kubelet/seccomp` and write the matching `localhostProfile` value.
- Read and write a profile with `defaultAction`, `architectures` and `syscalls`, and explain the difference between an allow list and a deny list.
- Verify from inside a container that a filter is installed and that a blocked syscall fails.
- Find the syscall that a profile blocks and repair a pod that fails because of its profile.

## Before you start

You need Kubernetes basics (pods, namespaces, `kubectl`) and basic Linux knowledge (processes, files, users). You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with a single control-plane node that also runs workloads. `kind` runs the node as a Podman container, and you run a command inside it with `podman exec`.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and the `probe` Service on port 80, and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
