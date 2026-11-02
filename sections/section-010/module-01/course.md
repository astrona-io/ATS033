---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Reduce The Host Operating-System Attack Surface

Every container on a Kubernetes node shares the node's Linux kernel, its container runtime and its files. If an attacker gains control of the node, the attacker controls every pod on it, no matter how carefully each pod is configured. The host operating system is therefore part of the cluster's security boundary, and every extra service, package or open interface on it is more code that an attacker can try to use.

Keep one sentence in mind for this module: **a node should run only what a node needs, and every other service, package and privileged interface should be found, justified or removed.** You will inventory what runs on a node, stop and disable an unneeded service so it stays off after a reboot, check packages before removing them, and review the interfaces that give a process host-level authority.

The module has four parts. **Inventory Services And Listeners** lists the running services, the enabled services and the network listeners of a node with `systemctl` and `ss`. **Stop, Disable And Mask Services** shows what each systemd action changes and which one survives a reboot. **Remove Packages And Keep The Node Working** uses `dpkg` and `apt-get` to find who owns a file, simulate a removal and check that the node still works. **Privileged Host Interfaces** reviews the container runtime socket, the kubelet configuration, host namespaces and `hostPath` volumes.

## Learning objectives

After this module you can:

- List the services, listening ports and installed packages of a Linux node and explain what each one is for.
- Explain why a stopped service can start again after a reboot, and choose between `stop`, `disable` and `mask`.
- Simulate the removal of a package and read the list of other packages it would remove.
- Check that the kubelet, the container runtime and the API still work after a hardening change.
- Name the host interfaces that give a process administrator-level authority: the runtime socket, `hostPath` volumes, host namespaces and privileged containers.

## Before you start

You need basic Linux skills (files, users, running commands as root) and Kubernetes basics (nodes, pods, namespaces, `kubectl get` and `kubectl apply`). You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35. It has one control-plane node and one worker node. `kind` runs each node as a Podman container that runs systemd, so a node behaves like a small Linux host. You reach a node with `podman exec`, which runs one command inside the node container as root. Every host-level command in this module names the node containers of this playground only.

| Where | What is in it |
| --- | --- |
| `starfleet` namespace | The `probe` Deployment with two replicas, the `probe` Service and the `shuttle` client pod |
| `outpost` namespace | The `drifter` client pod |
| Control-plane node | The seeded systemd service `training-extra.service`, which is running and enabled but has no job in the cluster |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
