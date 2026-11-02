---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Summary

External access is limited in layers, and each layer stops a different kind of traffic. The bind address of a service decides on which interface it listens: loopback accepts only local processes, and `0.0.0.0` accepts every IPv4 interface. A client sees `Connection refused` when the packet reaches the host and no process listens, and sees a timeout when something drops the packet. That difference tells the administrator whether to look at the service or at a filter.

A host firewall works in the kernel and does not depend on the service. In `iptables`, the `INPUT` chain holds rules for packets to the node, rules are checked from top to bottom, and the first match decides. Allow rules for known sources go before the drop rule. Rules from `iptables` are lost at reboot unless a persistence service restores them, and Kubernetes manages the chains that begin with `KUBE-`.

Inside the cluster, pods accept all traffic until a NetworkPolicy selects them. The CNI plugin enforces policies, policies only add allowed traffic, and the `ports` field matches the container port. A default-deny policy with an empty `podSelector`, followed by one allow policy per needed path, is the standard pattern. Pods with `hostNetwork: true` need a bind address or a host firewall instead.

Services publish access on purpose. A `NodePort` opens a port on every node, and a `LoadBalancer` exposes the Service through the cloud provider. The control-plane ports 6443, 2379, 2380 and 10250 must be reachable only from the networks and components that need them.

Key facts:

- Refused means a reachable host with no listener; a timeout means filtering or no route.
- The first matching `iptables` rule decides, so order the allow rules before the drop.
- Without an enforcing CNI plugin, a NetworkPolicy does nothing.
- A NodePort exists on every node of the cluster.
- etcd holds all Secrets, so its ports are restricted to the API servers and etcd members.

<!-- astrona:playground:destroy -->
