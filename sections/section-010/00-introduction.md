# Minimize The Host OS Footprint

Picture a worker node that still runs a print service, a mail daemon and a set of compilers left over from its first install. None of them is needed to run Pods. Each one is still a program that listens, parses input or can help an attacker who gets onto the node.

A container shares the kernel of its node. If an attacker controls the node, the isolation between containers no longer protects anything. This is why a hardened cluster starts with hardened nodes. In this section, you learn how to find what a node runs, remove what it does not need, close the ways people log in, and stop Pods from reaching into the host.

## What you will learn

The section moves from the node itself to the workloads that run on it:

- **Reduce The Host Operating-System Attack Surface.** Find services and listeners, stop, disable and mask the ones a node does not need, remove packages without breaking the node, and spot privileged host interfaces.
- **Harden Node Access With SSH And Host Login Paths.** Read the settings the SSH daemon really uses, limit who can log in, and close the login shells of accounts that should not log in.
- **Restrict Workload Access To The Host.** Host namespaces, `hostPath` volumes and privileged containers, Pod Security Admission to block them, and kubelet settings and dedicated nodes for workloads that need more.

## How this section works

Each module has its own playground. The first two modules work on the node itself, so their playground is a virtual machine (VM) that runs Ubuntu and a one-node Kubernetes cluster built with kubeadm. You log in to it with `astrona ssh`. The third module works with Pods, so its playground is a private `kind` cluster. Start the playground from the first page of the module and keep it running while you read.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh environment and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- list the services, packages and listeners of a node, and decide which ones it needs;
- stop, disable and mask a service, and remove a package without breaking the kubelet or the container runtime;
- explain why control of a node breaks the isolation of every container on it;
- read the effective SSH daemon settings, and limit root login, password login and the users who may log in;
- find accounts with a login shell they do not need, and close them;
- recognise Pods that use host namespaces, `hostPath` volumes or privileged mode, and block them with Pod Security Admission.
