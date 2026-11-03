---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Restrict Workload Access To The Host

A pod is meant to be a box around a process: its own network, its own process list and its own files. Several pod settings remove those limits on purpose, because some workloads, such as a network plugin or a log collector, need to see the node. The same settings give an attacker who controls such a pod a direct view of the node and often full control of it. Hardening a node therefore includes deciding which pods may reach the host and keeping every other pod away from it.

Keep one sentence in mind for this module: **a pod gets access to the host only when its job requires it, the API server rejects the rest, and sensitive workloads run on nodes that other workloads cannot use.** You will identify the settings that give host access, enforce limits with Pod Security Admission, check the kubelet API settings, and dedicate a node to a sensitive workload.

The module has three parts. **Host Namespaces, hostPath And Privileged Containers** shows what `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` and `privileged` each give a pod. **Enforce Limits With Pod Security Admission** shows how a namespace label makes the API server reject such pods and what happens to a Deployment under that label. **Kubelet Settings And Dedicated Nodes** checks the kubelet read-only port and anonymous access and uses a taint and a label to keep other workloads off a node.

## Learning objectives

After this module you can:

- Name what each of `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` and `privileged` gives a pod, and show the effect with a running pod.
- Apply the `baseline` and `restricted` Pod Security Standards with namespace labels and read the rejection.
- Explain why a Deployment is accepted under an `enforce` label while its pods are not created, and find the reason.
- Check the kubelet for anonymous access, the authorization mode and the read-only port 10255.
- Dedicate a node to a workload with a label, a node selector, a taint and a toleration, and explain the limits of each.

## Before you start

You need basic Kubernetes skills (pods, Deployments, namespaces, `kubectl apply`, `kubectl get`) and basic Linux skills. You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container that runs systemd. You reach a node with `podman exec`, which runs one command inside the node container as root. Every host-level command in this module names the node containers of this playground only.

| Where | What is in it |
| --- | --- |
| `starfleet` namespace | The `probe` Deployment with two replicas, the `probe` Service, the `shuttle` client pod and the `beacon` Deployment, which has host access |
| `outpost` namespace | The `drifter` client pod |
| Both nodes | The kubelet with its configuration file `/var/lib/kubelet/config.yaml` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
