# Restrict Access To The API Server And Control-Plane Ports

The control plane is the group of components that decides what runs in the cluster. Its network ports are the most valuable targets in the cluster. The API server accepts every change. The kubelet on each node can run commands in containers. etcd holds every Secret in the cluster.

Each of these components has its own port, its own list of expected callers and its own authentication setting. A cluster is only as safe as the weakest of them. So you must check every port, not only the API server.

Keep one sentence in mind for this module: **every control-plane port needs two controls, a network rule that limits who can connect and an authentication and authorization setting that limits what a connected caller can do.** You will read the listeners of a control-plane node, check the authentication and authorization settings of the API server, close the kubelet API to anonymous callers, and review how etcd accepts clients.

## What you will learn

After this module, you can:

- name the ports 6443, 10250, 2379, 2380, 10257 and 10259, the component behind each, and the callers that should reach them;
- read the listeners of a node with `ss` and tell which ones accept remote connections;
- explain `--anonymous-auth` and `--authorization-mode` and test them with an unauthenticated request;
- set the kubelet to reject anonymous requests and to authorize through the API server;
- check that etcd requires client certificates and listens only where it must.

## How the module is laid out

You start with **Control-Plane Ports And Listeners**, which names each port, its component and its expected callers, and reads the listeners with `ss`. **API Server Authentication And Authorization** then reads the flags `--anonymous-auth` and `--authorization-mode` and tests what an anonymous caller can do. **Kubelet API Authentication And Authorization** shows how an open kubelet gives control of a node, and how to close it. **etcd Client Access** closes the module. It reviews how etcd accepts clients and why only the API servers may reach it.

## Before you start

You need basic Kubernetes knowledge: nodes, pods, static pods and kubeconfig files. You also need basic TLS (Transport Layer Security) knowledge, such as what a certificate and a certificate authority are. Finally, you should know what a listener and a bind address are: a listener is a process that waits for connections on a port, and the bind address is the network address it waits on.

## Your playground

Your playground is a VM (virtual machine) that runs Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster built with kubeadm. kubeadm is the standard tool that installs a cluster on a Linux machine. The single node is the control plane and also runs the pods. So the static pod manifests, the kubelet configuration file and the etcd data directory are real files on that VM.

You open a shell on the VM with `astrona ssh`, work as the `student` user, and run node commands with `sudo`. The `student` user already has a kubeconfig file for the cluster. The cluster already runs these workloads:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server that listens on port 8080 |
| `starfleet` | `probe-code` ConfigMap | Holds `server.py`, the code of the `probe` web server |
| `starfleet` | `probe` Service | Port 80, forwards to the `http` port (8080) of the `probe` pods |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A `busybox` client pod |
| `outpost` | `drifter` pod, label `app: drifter` | A `busybox` client pod, in another namespace |

The playground also sets the kubelet on the node to an unsafe configuration on purpose. It accepts anonymous requests and allows every request. You will find this setting and repair it.

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
