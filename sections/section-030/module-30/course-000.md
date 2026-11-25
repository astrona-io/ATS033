---
exam_objectives:
- Minimize external access to the network
---
# Restrict Access To The API Server And Control-Plane Ports

The control plane decides what runs in the cluster, and its network ports are the most valuable targets. The API server accepts every change. The kubelet on each node can run commands in containers. etcd holds every Secret in the cluster. Each of these components has its own port, its own caller list and its own authentication setting, and a cluster is only as safe as the weakest of them.

Keep one sentence in mind for this module: **every control-plane port needs two controls, a network rule that limits who can connect and an authentication and authorization setting that limits what a connected caller can do.** You will read the listeners of a control-plane node, check the authentication and authorization settings of the API server, close the kubelet API to anonymous callers, and review how etcd accepts clients.

The module has four parts. **Control-Plane Ports And Listeners** names each port, its component and its expected callers, and reads the listeners with `ss`. **API Server Authentication And Authorization** reads the flags `--anonymous-auth` and `--authorization-mode` and tests what an anonymous caller can do. **Kubelet API Authentication And Authorization** shows how an open kubelet gives control of a node and how to close it. **etcd Client Access** reviews how etcd accepts clients and why it must be reachable only by the API servers.

## Learning objectives

After this module you can:

- Name the ports 6443, 10250, 2379, 2380, 10257 and 10259, the component behind each, and the callers that should reach them.
- Read the listeners of a node with `ss` and tell which ones accept remote connections.
- Explain `--anonymous-auth` and `--authorization-mode` and test them with an unauthenticated request.
- Set the kubelet to reject anonymous requests and to authorize through the API server.
- Check that etcd requires client certificates and listens only where it must.

## Before you start

You need basic Kubernetes knowledge (nodes, pods, static pods, kubeconfig), basic TLS knowledge (certificate, certificate authority) and the idea of a listener and a bind address.

Your playground is a VM (virtual machine) that runs a one-node Kubernetes 1.35 cluster built with kubeadm. kubeadm is the standard tool that installs a cluster on a Linux machine. The single node is the control plane and also runs the pods, so the static pod manifests, the kubelet configuration file and the etcd data directory are real files on that VM.

You open a shell on it with `astrona ssh`, work as the `student` user, and run node commands with `sudo`. The kubelet on the node is deliberately set to an unsafe configuration, which you will find and repair.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas, the `probe` Service and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
