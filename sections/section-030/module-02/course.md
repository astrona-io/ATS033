---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Limit Service Exposure Outside The Cluster

A Kubernetes Service gives pods a stable address, and its `type` field decides how far that address reaches. A Service of type `NodePort` opens a port on every node of the cluster. A Service of type `LoadBalancer` asks the cloud provider for a public address. Both are often created for a short test and then forgotten, and each one is a path from the outside network to a pod.

Keep one sentence in mind for this module: **a Service should be reachable from outside the cluster only when someone decided that it must be, and then only from the clients and nodes that need it.** You will list the Services that publish access, close one that no one needs, narrow the ones that stay, and see why an Ingress is the usual single entry point.

The module has three parts. **Service Types And What They Open** compares `ClusterIP`, `NodePort` and `LoadBalancer`, shows which component opens each port, and finds the Services that publish access. **Narrowing NodePorts And Load Balancers** uses `externalTrafficPolicy` and `loadBalancerSourceRanges` to limit who and what a published Service reaches. **Ingress As The Single Entry Point** explains why one Ingress controller replaces many published Services and how to audit a cluster for accidental exposure.

## Learning objectives

After this module you can:

- Explain what `ClusterIP`, `NodePort` and `LoadBalancer` open and name the component that opens it.
- List every Service that publishes access outside the cluster and decide which ones to remove.
- Change a `NodePort` Service back to `ClusterIP`.
- Explain what `externalTrafficPolicy: Local` and `loadBalancerSourceRanges` change.
- Explain why an Ingress controller reduces the number of exposed ports.

## Before you start

You need basic Kubernetes knowledge (pods, Services, labels, namespaces) and basic networking knowledge (IP address, TCP port, client and server).

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas, the `probe` Service of type `ClusterIP`, the Services `probe-admin` (type `NodePort`) and `probe-edge` (type `LoadBalancer`), and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Both client pods run BusyBox, which provides `wget` for test requests. Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
