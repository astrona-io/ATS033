# Kernel Hardening With seccomp And AppArmor

A container is not a small virtual machine. Every container on a node shares the kernel of that node. So a process that escapes its normal limits attacks the same kernel as every other container on the node.

Namespaces and cgroups (control groups) already separate what a process can see and how much it can use. But they do not limit which kernel features the process may call. Kernel hardening adds two such limits. The first limits the system calls a process can make. The second limits the files, capabilities and network operations it can use.

Keep one sentence in mind for this module: **seccomp restricts which system calls a process can make, AppArmor restricts which resources it can touch, and Kubernetes selects both with fields in the securityContext.** The securityContext is the part of a pod or container specification that holds its security settings.

## What you will learn

After this module, you can:

- explain what a system call is and what seccomp filters;
- choose between `RuntimeDefault`, `Localhost` and `Unconfined` for a seccomp profile, and read the result in `/proc/1/status`;
- explain what an AppArmor profile restricts, the difference between enforce mode and complain mode, and what a node needs before a pod can use a profile;
- write a securityContext with `appArmorProfile`, `seccompProfile`, `allowPrivilegeEscalation: false`, dropped capabilities and a read-only root filesystem;
- diagnose a pod that cannot start because a profile is missing, and decide what to change.

## How the module is laid out

You start with **Seccomp: Filtering System Calls**. It covers the three profile types, shows the seccomp state of a process in `/proc`, and loads a custom seccomp profile on a node. **AppArmor: Profiles For Files And Capabilities** then covers the profile modes, what the node must provide and the `appArmorProfile` field.

**The Restricted Security Context** combines both kernel profiles with the other container settings that Pod Security Admission expects. **Diagnosing Profile Failures** closes the module. It shows how to read the symptoms when a profile is missing or too strict, and how to fix them without removing the protection.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: pods, namespaces and `kubectl`. You also need basic Linux knowledge: processes, files and users.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes 1.35, with a single control-plane node that also runs workloads. `kind` runs the node as a Podman container, and you run a command inside the node with `podman exec`.

The node container shares the kernel of the machine that runs Podman. So the kernel features you can use depend on that machine. This matters most for AppArmor, as the page about AppArmor explains. The cluster already runs these workloads:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, label `app: probe` | A small Python web server that listens on port 8080 |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | The server code that the `probe` pods run |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A BusyBox client pod |
| `outpost` | `drifter` pod, label `app: drifter` | A BusyBox client pod, in another namespace |

Start your playground now and keep it running next to you while you read:

<!-- astrona:playground -->
