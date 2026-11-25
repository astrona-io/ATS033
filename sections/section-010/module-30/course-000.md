# Restrict Workload Access To The Host

A pod normally runs inside walls of its own. It has its own network, its own list of processes and its own files. Several pod settings remove those walls on purpose, because some workloads need to see the node. A network plugin and a log collector are two examples.

The same settings are a danger in the wrong pod. An attacker who controls such a pod gets a direct view of the node, and often full control of it. So hardening a node includes two decisions: which pods may reach the host, and how to keep every other pod away from it.

Keep one sentence in mind for this module: **a pod gets access to the host only when its job requires it, the API server rejects the rest, and sensitive workloads run on nodes that other workloads cannot use.**

## What you will learn

After this module, you can:

- name what each of `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` and `privileged` gives a pod, and show the effect with a running pod;
- apply the `baseline` and `restricted` Pod Security Standards with namespace labels, and read the rejection;
- explain why a Deployment is accepted under an `enforce` label while its pods are not created, and find the reason;
- check the kubelet for anonymous access, the authorization mode and the read-only port 10255;
- dedicate a node to a workload with a label, a node selector, a taint and a toleration, and explain the limits of each.

## How the module is laid out

You start with **Host Namespaces, hostPath And Privileged Containers**. It shows what `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` and `privileged` each give a pod. **Enforce Limits With Pod Security Admission** then shows how a label on a namespace makes the API server reject such pods, and what happens to a Deployment under that label. **Kubelet Settings And Dedicated Nodes** closes the module. It checks the kubelet read-only port and anonymous access, and it uses a taint and a label to keep other workloads off a node.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: pods, Deployments and namespaces. You should also be able to use `kubectl apply` and `kubectl get`, and know basic Linux commands. You do not need any earlier module.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes v1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container, and that container runs systemd. You reach a node with `podman exec`, which runs one command inside the node container as root. Every host-level command in this module names the node containers of this playground only.

The cluster already runs these objects:

| Where | Object | What it is |
| --- | --- | --- |
| `starfleet` namespace | `probe` Deployment, two pods, label `app: probe` | A small Python web server that listens on port 8080, with its code in the `probe-code` ConfigMap |
| `starfleet` namespace | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` namespace | `shuttle` pod, label `app: shuttle` | A `busybox` client pod |
| `starfleet` namespace | `beacon` Deployment, one pod, label `app: beacon` | A `busybox` pod with host access: `hostNetwork`, `hostPID`, a privileged container and a `hostPath` volume of `/var/log` |
| `outpost` namespace | `drifter` pod, label `app: drifter` | A `busybox` client pod, in another namespace |
| Both nodes | `astro-ats-033-playground-010-03-control-plane` and `astro-ats-033-playground-010-03-worker` | The kubelet on each node, with its configuration file `/var/lib/kubelet/config.yaml` |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
