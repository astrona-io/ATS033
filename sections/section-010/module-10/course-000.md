# Reduce The Host Operating-System Attack Surface

Every container on a Kubernetes node shares the node's Linux kernel, its container runtime and its files. If an attacker gains control of the node, the attacker controls every pod on it. It does not matter how carefully each pod is configured. The host operating system is therefore part of the security boundary of the cluster.

The attack surface is all the code on the node that an attacker can try to use. Every extra service, package or open interface on the host makes it larger. Keep one sentence in mind for this module: **a node should run only what a node needs, and every other service, package and privileged interface should be found, justified or removed.**

In this module, you list what runs on a node and stop an unneeded service so that it stays off after a reboot. You check packages before you remove them. You also review the interfaces that give a process authority over the whole host.

## What you will learn

After this module, you can:

- list the services, listening ports and installed packages of a Linux node, and explain what each one is for;
- explain why a stopped service can start again after a reboot, and choose between `stop`, `disable` and `mask`;
- simulate the removal of a package and read the list of other packages it would remove;
- check that the kubelet, the container runtime and the API still work after a hardening change;
- name the host interfaces that give a process administrator-level authority: the runtime socket, `hostPath` volumes, host namespaces and privileged containers.

## How the module is laid out

You start with **Inventory Services And Listeners**, which lists the running services, the enabled services and the network listeners of a node with `systemctl` and `ss`. **Stop, Disable And Mask Services** then shows what each systemd action changes and which one survives a reboot. **Remove Packages And Keep The Node Working** uses `dpkg` and `apt-get` to find who owns a file, simulate a removal and check that the node still works. **Privileged Host Interfaces** closes the module with the container runtime socket, the kubelet configuration, host namespaces and `hostPath` volumes.

A graded lab follows the service part and another follows the package part, so you can practise those skills right away.

## Before you start

You need basic Linux skills: files, users and running commands as root. You also need the Kubernetes basics: nodes, pods, namespaces, `kubectl get` and `kubectl apply`.

## Your playground

Your playground is a virtual machine (VM) that runs Ubuntu 24.04. kubeadm, the standard tool that installs a cluster on a Linux machine, built a one-node Kubernetes v1.35.10 cluster on it. The node is the control plane and also runs the pods. It is a real Linux host with systemd, `apt` and an SSH server, so every command in this module runs on the node itself.

You open a shell on it with `astrona ssh astro-ats-033-playground-010-01`. You log in as the `student` user. This user has a kubeconfig file for the cluster and runs node commands with `sudo`. Those commands change only the playground VM, not your own computer. The playground already contains these objects:

| Where | Object | What it is |
| --- | --- | --- |
| `starfleet` namespace | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server that listens on port 8080 |
| `starfleet` namespace | `probe-code` ConfigMap | The code of the web server, mounted into the `probe` pods |
| `starfleet` namespace | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` namespace | `shuttle` pod, label `app: shuttle` | A client pod that runs `busybox` |
| `outpost` namespace | `drifter` pod, label `app: drifter` | A client pod that runs `busybox`, in another namespace |
| The node | `training-extra.service` | A seeded systemd service that runs `/bin/sleep 3600`. It is running and enabled but has no job in the cluster |
| The node | `node-diag-tools` package | A seeded package that installs `/usr/bin/node-diag`, a debugging script that nothing needs |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
