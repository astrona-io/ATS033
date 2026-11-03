---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Summary

The type of a Service decides how far it reaches. A `ClusterIP` Service is reachable inside the cluster only. A `NodePort` Service also opens a port on every node, and the `kube-proxy` component on each node programs the rules that forward it, so the port is open on nodes that run none of the pods. A `LoadBalancer` Service adds an external load balancer, which the cloud provider integration creates. Without that integration, as in a local `kind` cluster, the external address stays pending.

The first review step is an inventory: list every Service that is not of type `ClusterIP`, and every Service that sets `externalIPs`. Each one needs an owner and a reason. A Service created for a test and never deleted is the most common accidental exposure. The fix is to change the type back to `ClusterIP`, which releases the node port.

Services that must stay published can be narrowed. With `externalTrafficPolicy: Local`, a node forwards traffic only to its own pods, keeps the client address, and drops the traffic when it has no ready pod. With `loadBalancerSourceRanges`, the platform restricts a load balancer to listed client ranges. The field does nothing for a `NodePort` Service, and it works only where the platform enforces it.

An Ingress controller replaces many published Services with one entry point and keeps the applications at `ClusterIP`. An Ingress object does nothing without a controller, and an Ingress does not remove the older node ports that still bypass it. A complete audit checks Service types, `externalIPs`, Ingress objects and host-network pods.

Key facts:

- `NodePort` opens the port on every node, not only on nodes with pods.
- A `LoadBalancer` Service also has a node port and a cluster address.
- `externalTrafficPolicy: Local` keeps the client address and drops traffic on nodes without ready pods.
- `loadBalancerSourceRanges` is read by the platform, and only for `LoadBalancer` Services.
- An Ingress is enforced by an Ingress controller, which needs one published Service of its own.

<!-- astrona:playground:destroy -->
