---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Confine Workloads With AppArmor And Capabilities

A process in a container often runs as root inside its own namespaces. Root there is not harmless: the process may hold Linux capabilities, may gain more rights through a setuid program, and may touch any file its user can reach. Three controls narrow this. AppArmor limits the files, capabilities and network operations a program can use, by name. Linux capabilities split the power of root into small units that you can remove. The fields `allowPrivilegeEscalation` and `privileged` decide whether a process can gain rights or receive all of them.

Keep one sentence in mind for this module: **AppArmor says what a program may touch, capabilities say which root powers it keeps, and the securityContext selects both.** You will learn the two AppArmor modes and how to load a profile on a node, select the profile in a pod, and then drop capabilities and block privilege escalation in a pod that runs without `privileged`.

The module has three parts. **AppArmor Modes And Loading Profiles** covers enforce and complain mode, `apparmor_parser` and the need to load a profile on every node. **Select A Profile With appArmorProfile** covers the pod fields and how to verify them. **Drop Capabilities And Block Privilege Escalation** covers capabilities, `allowPrivilegeEscalation: false` and `privileged: false`.

## Learning objectives

After this module you can:

- Explain the AppArmor enforce and complain modes and load a profile with `apparmor_parser`.
- Explain why a profile must be loaded on every node that can run the pod.
- Select a profile with `securityContext.appArmorProfile` at pod and container level and verify it from inside the container.
- Drop Linux capabilities, add back only the one that is needed, and read the result in `/proc/1/status`.
- Set `allowPrivilegeEscalation: false` and `privileged: false`, and explain what each one prevents.

## Before you start

You need Kubernetes basics (pods, namespaces, `kubectl`) and basic Linux knowledge (processes, users, files).

Your playground is a virtual machine (VM) that runs Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster built with kubeadm. The VM is the node, and its kernel has AppArmor enabled, so every AppArmor step works in it. You open a shell on the VM with `astrona ssh astro-ats-033-playground-040-03`. There you are the user `student`, `kubectl` already points to the cluster, and you run node commands such as `apparmor_parser` with `sudo`.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and the `probe` Service on port 80, and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
