---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Kernel Hardening With seccomp And AppArmor

A container is not a small virtual machine. Every container on a node shares the kernel of that node, so a process that escapes its normal limits attacks the same kernel as every other container. Namespaces and cgroups separate what a process can see and use, but they do not limit which kernel features the process may call. Kernel hardening adds two such limits: one on the system calls a process can make, and one on the files, capabilities and network operations it can use.

Keep one sentence in mind for this module: **seccomp restricts which system calls a process can make, AppArmor restricts which resources it can touch, and Kubernetes selects both with fields in the securityContext.** You will inspect the seccomp state of a running process, load a custom seccomp profile on a node, learn how an AppArmor profile is loaded and referenced, build a restricted pod, and diagnose the failures that a missing profile causes.

The module has four parts. **Seccomp: Filtering System Calls** covers the three profile types and shows the state of a process in `/proc`. **AppArmor: Profiles For Files And Capabilities** covers modes, node prerequisites and the `appArmorProfile` field. **The Restricted Security Context** combines both with the other container settings that Pod Security Admission expects. **Diagnosing Profile Failures** shows how to read the symptoms when a profile is missing or too strict, and how to fix them without removing the protection.

## Learning objectives

After this module you can:

- Explain what a system call is and what seccomp filters.
- Choose between `RuntimeDefault`, `Localhost` and `Unconfined` for a seccomp profile and read the result in `/proc/1/status`.
- Explain what an AppArmor profile restricts, the difference between enforce and complain mode, and what a node needs before a pod can use a profile.
- Write a securityContext with `appArmorProfile`, `seccompProfile`, `allowPrivilegeEscalation: false`, dropped capabilities and a read-only root filesystem.
- Diagnose a pod that cannot start because a profile is missing, and decide what to change.

## Before you start

You need Kubernetes basics (pods, namespaces, `kubectl`) and basic Linux knowledge (processes, files, users). You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with a single control-plane node that also runs workloads. `kind` runs the node as a Podman container, and you run a command inside it with `podman exec`. The node container shares the kernel of the machine that runs Podman, so which kernel features are available depends on that machine. This matters most for AppArmor, as the second part explains.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and the `probe` Service on port 80 |
| `outpost` | A namespace with no workloads that you can use for tests |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
