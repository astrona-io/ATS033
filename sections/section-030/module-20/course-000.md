# Limit Service Exposure Outside The Cluster

A Kubernetes Service gives a group of pods one stable address. Its `type` field decides how far that address reaches. A Service of type `NodePort` opens a port on every node of the cluster. A Service of type `LoadBalancer` asks the cloud provider for a public address.

Both types are often created for a short test and then forgotten. Each one is a path from the outside network to a pod. An attacker who finds such a path can send requests to the application without passing any of the controls you planned.

Keep one sentence in mind for this module: **a Service should be reachable from outside the cluster only when someone decided that it must be, and then only from the clients and nodes that need it.** You will list the Services that publish access, close one that no one needs, narrow the ones that stay, and see why an Ingress is the usual single entry point.

## What you will learn

After this module, you can:

- explain what `ClusterIP`, `NodePort` and `LoadBalancer` open, and name the component that opens it;
- list every Service that publishes access outside the cluster and decide which ones to remove;
- change a `NodePort` Service back to `ClusterIP`;
- explain what `externalTrafficPolicy: Local` and `loadBalancerSourceRanges` change;
- explain why an Ingress controller reduces the number of exposed ports.

## How the module is laid out

You start with **Service Types And What They Open**. It compares `ClusterIP`, `NodePort` and `LoadBalancer`, shows which component opens each port, and finds the Services that publish access. **Narrowing NodePorts And Load Balancers** then uses `externalTrafficPolicy` and `loadBalancerSourceRanges` to limit who a published Service accepts and which nodes forward its traffic. **Ingress As The Single Entry Point** closes the module. It explains why one Ingress controller replaces many published Services, and how to audit a cluster for exposure that nobody planned.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: pods, Services, labels and namespaces. You should also know basic networking words: IP address, TCP port, client and server.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes 1.35, with one control-plane node and one worker node. `kind` runs each node as a Podman container. The cluster already runs these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server that listens on port 8080 (port name `http`) |
| `starfleet` | `probe-code` ConfigMap | The server code that the `probe` pods run |
| `starfleet` | `probe` Service, type `ClusterIP` | Port 80, forwards to the `http` port of the `probe` pods |
| `starfleet` | `probe-admin` Service, type `NodePort` | Port 80, also published on node port 30090 of every node |
| `starfleet` | `probe-edge` Service, type `LoadBalancer` | Port 80, with a node port that the API server picks |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A BusyBox client pod with `wget` |
| `outpost` | `drifter` pod, label `app: drifter` | A BusyBox client pod with `wget`, in another namespace |

Each page selects the private kubeconfig of the playground before its first command. A kubeconfig is the file that tells `kubectl` which cluster to use and which credentials to send. Start your playground now and keep it running while you read:

<!-- astrona:playground -->
