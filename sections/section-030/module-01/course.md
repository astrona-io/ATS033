---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Minimize External Access To The Network

A service that listens where nobody needs it can be attacked by anyone who can reach that address. A management interface that listens on every network interface of a node, while only administrators on one protected network use it, is exposed to every machine and every pod that can route to the node. Reducing external access means that each listener is reachable only by the callers that need it, on the narrowest address, port and path possible.

Keep one sentence in mind for this module: **limit exposure in layers, because the bind address of a service, the firewall of the node and the NetworkPolicy of the cluster each stop a different kind of traffic.** You will see the difference between listening on loopback and on all interfaces, tell a refused connection from a timed-out one, filter traffic with a host firewall rule, restrict pod traffic with NetworkPolicy and review the cluster services that open node ports.

The module has four parts. **Listeners And Bind Addresses** compares a service on all interfaces with one on loopback and tests both from a pod. **Host Firewalls With iptables And ufw** adds and removes a packet filter rule on the node and shows why a dropped packet looks different from a refused one. **NetworkPolicy For Pod Traffic** denies all ingress in a namespace and allows one client. **NodePorts, Control-Plane Ports And API Access** reviews the Service types and the ports that give access from outside.

## Learning objectives

After this module you can:

- Read `ss` output and tell which listeners accept connections from other machines.
- Explain the difference between `Connection refused` and a connection timeout.
- Add, list and remove a rule in the `INPUT` chain with `iptables`, and name the tools that make rules persistent.
- Write a NetworkPolicy that denies ingress by default and allows one client to one port.
- Find Services of type `NodePort` and `LoadBalancer`, and name the control-plane ports that must not be open to the internet.

## Before you start

You need basic networking knowledge (IP addresses, TCP ports, client and server) and Kubernetes basics (pods, Services, namespaces, labels). You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container, and you run a command inside a node with `podman exec`. Every host-level command names the node containers of this playground only.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas, the `probe` Service on port 80 and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Both client pods run BusyBox, which provides `wget` for test requests. Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
