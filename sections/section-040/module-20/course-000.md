# Apply seccomp Profiles To Pods

A container shares the kernel of its node, and the kernel offers several hundred system calls. A system call (syscall) is a request that a process sends to the kernel, for example to open a file, create a directory or change a permission. Most applications need only a small part of them. But a pod without a filter may call all of them.

seccomp (secure computing mode) is the kernel feature that filters syscalls. A seccomp profile is the file that tells the kernel which syscalls a process may make. With a profile in place, a flaw in a rarely used kernel feature is much harder to reach from inside a container.

Keep one sentence in mind for this module: **a seccomp profile is a JSON document with a default action and a list of syscall rules, the kubelet reads it from a directory on the node, and a pod selects it with `securityContext.seccompProfile`.** You will compare the three profile types, write a profile that blocks one group of syscalls, copy it to the node, run a pod under it, and read the failures that a wrong or missing profile causes.

## What you will learn

After this module, you can:

- choose between `RuntimeDefault`, `Localhost` and `Unconfined`, and explain the risk of `Unconfined`;
- place a profile file under `/var/lib/kubelet/seccomp` and write the matching `localhostProfile` value;
- read and write a profile with `defaultAction`, `architectures` and `syscalls`, and explain the difference between an allow list and a deny list;
- check from inside a container that a filter is installed and that a blocked syscall fails;
- find the syscall that a profile blocks and repair a pod that fails because of its profile.

## How the module is laid out

You start with **Profile Types, Locations And The Unconfined Risk**. It covers `RuntimeDefault`, `Localhost` and `Unconfined`, the directory `/var/lib/kubelet/seccomp`, and what a pod without a filter costs. **Write And Load A Localhost Profile** then explains the JSON structure with `defaultAction` and `syscalls`, and loads a profile on a node. **Find Blocked Syscalls And Fix Failures** closes the module. It shows how to tell which syscall a profile blocked and how to repair a pod that cannot start.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: pods, namespaces and `kubectl`. You should also know some basic Linux: processes, files and users.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes v1.35. It has a single control-plane node that also runs workloads. `kind` runs the node as a Podman container, and you run a command inside the node with `podman exec`. The cluster already runs these workloads:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server that listens on port 8080 |
| `starfleet` | `probe-code` ConfigMap | The server code that the `probe` pods mount |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A BusyBox client pod that sleeps |
| `outpost` | `drifter` pod, label `app: drifter` | A BusyBox client pod that sleeps, in another namespace |

No custom seccomp profile exists on the node yet. Start your playground now and keep it running while you read:

<!-- astrona:playground -->
