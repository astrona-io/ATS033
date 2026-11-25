# Use Kernel Hardening Tools Such As AppArmor And seccomp

Picture a process in a container that is allowed to open a file but then makes a system call it has no reason to make. A file rule cannot stop that call, because it controls which files the process may touch, not which kernel functions it may ask for.

The Linux kernel offers tools for both problems. seccomp filters the system calls a process may make. AppArmor limits the files, capabilities and other resources a process may use. Each protects a different part of the same container. In this section, you learn how each tool works, how to choose and load a profile, and how to fix a Pod that a profile breaks.

## What you will learn

The section moves from the ideas to each tool in depth:

- **Kernel Hardening With seccomp And AppArmor.** How seccomp filters system calls, how AppArmor profiles limit files and capabilities, the restricted security context, and how to find which profile broke a Pod.
- **Apply seccomp Profiles To Pods.** The profile types and where Localhost profiles live, the risk of running unconfined, writing and loading your own profile, and finding the blocked system call that makes a Pod fail.
- **Confine Workloads With AppArmor And Capabilities.** AppArmor modes and loading profiles on the node, selecting a profile with `appArmorProfile`, dropping capabilities and blocking privilege escalation.

## How this section works

Each module has its own playground. The first two modules use a private `kind` cluster. The third module loads AppArmor profiles into the kernel of a real node, so its playground is a virtual machine (VM) that runs Ubuntu and a one-node Kubernetes cluster built with kubeadm. You log in to it with `astrona ssh`. Start the playground from the first page of the module and keep it running while you read.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh environment and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- explain the difference between filtering system calls and limiting access to files and capabilities;
- choose between the `RuntimeDefault`, `Localhost` and `Unconfined` profile types;
- explain what a node needs before a profile works, and how a container setting overrides a Pod setting;
- write and load a Localhost seccomp profile and an AppArmor profile;
- drop capabilities and block privilege escalation in a security context;
- find the profile that breaks a Pod, and fix it without opening the boundary again.
