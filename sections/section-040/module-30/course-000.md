# Confine Workloads With AppArmor And Capabilities

A process in a container often runs as root inside its own namespaces. Root there is not harmless. The process may hold Linux capabilities, it may gain more rights through a setuid program, and it may touch any file its user can reach.

Three controls narrow this. AppArmor limits the files, capabilities and network operations a program can use, by name. Linux capabilities split the power of root into small units that you can remove. The fields `allowPrivilegeEscalation` and `privileged` decide whether a process can gain rights or receive all of them.

Keep one sentence in mind for this module: **AppArmor says what a program may touch, capabilities say which root powers it keeps, and the securityContext selects both.** The securityContext is the part of a pod or container specification that holds its security settings.

## What you will learn

After this module, you can:

- explain the AppArmor enforce and complain modes, and load a profile with `apparmor_parser`;
- explain why a profile must be loaded on every node that can run the pod;
- select a profile with `securityContext.appArmorProfile` at pod level and at container level, and check it from inside the container;
- drop Linux capabilities, add back only the one that is needed, and read the result in `/proc/1/status`;
- set `allowPrivilegeEscalation: false` and `privileged: false`, and explain what each one prevents.

## How the module is laid out

You start with **AppArmor Modes And Loading Profiles**. It covers enforce mode and complain mode, the loader tool `apparmor_parser`, and why every node needs the profile. **Select A Profile With appArmorProfile** then covers the pod fields and how to check which profile a container runs under.

**Drop Capabilities And Block Privilege Escalation** closes the module. It covers capabilities, `allowPrivilegeEscalation: false` and `privileged: false`, and shows how to read each of them in `/proc`.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: pods, namespaces and `kubectl`. You also need basic Linux knowledge: processes, users and files.

## Your playground

Your playground is a virtual machine (VM) that runs Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster built with kubeadm. The VM is the node, and its kernel has AppArmor enabled, so every AppArmor step works in it.

You open a shell on the VM with `astrona ssh astro-ats-033-playground-040-03`. There you are the user `student`, and `kubectl` already points to the cluster. You run node commands such as `apparmor_parser` with `sudo`. The cluster already runs these workloads:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, label `app: probe` | A small Python web server that listens on port 8080 |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | The server code that the `probe` pods run |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A BusyBox client pod |
| `outpost` | `drifter` pod, label `app: drifter` | A BusyBox client pod, in another namespace |

Start your playground now and keep it running next to you while you read:

<!-- astrona:playground -->
