# Minimize External Access To The Network

A service that listens where nobody needs it can be attacked by anyone who can reach that address. Think of a management interface that listens on every network interface of a node, while only administrators on one protected network use it. Every machine and every pod that can route to the node can reach that interface.

Reducing external access means that each listener is reachable only by the callers that need it. It should use the narrowest address, port and network path possible.

Keep one idea in mind for this module: **limit exposure in layers.** The bind address of a service, the firewall of the node and the NetworkPolicy of the cluster each stop a different kind of traffic. No single layer covers all of them.

## What you will learn

After this module, you can:

- read `ss` output and tell which listeners accept connections from other machines;
- explain the difference between `Connection refused` and a connection timeout;
- add, list and remove a rule in the `INPUT` chain with `iptables`, and name the tools that make rules persistent;
- write a NetworkPolicy that denies ingress by default and allows one client to one port;
- find Services of type `NodePort` and `LoadBalancer`, and name the control-plane ports that must not be open to the internet.

## How the module is laid out

You start with **Listeners And Bind Addresses**, which compares a service that listens on all interfaces with one that listens on loopback, and tests both from a pod. **Host Firewalls With iptables And ufw** then adds and removes a packet filter rule on the node, and shows why a dropped packet looks different from a refused one.

**NetworkPolicy For Pod Traffic** denies all incoming traffic in a namespace and then allows one client. **NodePorts, Control-Plane Ports And API Access** closes the module with the Service types and the cluster ports that give access from outside.

A lab follows the parts it practises, so you can use each skill right away.

## Before you start

You need basic networking knowledge: IP addresses, TCP ports, and the idea of a client and a server. You also need the Kubernetes basics: pods, Services, namespaces and labels. You should be able to use `kubectl get`, `kubectl apply` and `kubectl exec`.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes v1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container, and you run a command inside a node with `podman exec`. Every host-level command in this module names the node containers of this playground only. The cluster already runs these workloads:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server that listens on container port 8080 (port name `http`) |
| `starfleet` | `probe-code` ConfigMap | Holds `server.py`, the code of the `probe` web server |
| `starfleet` | `probe` Service | Port 80, forwards to the `http` port (8080) of the `probe` pods |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A BusyBox client pod with `wget` for test requests |
| `outpost` | `drifter` pod, label `app: drifter` | A BusyBox client pod with `wget`, in another namespace |

`kubectl` uses a private kubeconfig for this playground, which each part selects first. Start your playground now and keep it running while you read:

<!-- astrona:playground -->
