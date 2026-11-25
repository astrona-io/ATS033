# Summary

The type of a Service decides how far it reaches. A `ClusterIP` Service is reachable inside the cluster only. A `NodePort` Service also opens a port on every node. The `kube-proxy` component on each node programs the rules that forward that port, so the port is open even on nodes that run none of the pods. A `LoadBalancer` Service adds an external load balancer, which the cloud provider integration creates. Without that integration, as in a local `kind` cluster, the external address stays pending.

The first review step is an inventory. List every Service that is not of type `ClusterIP`, and every Service that sets `externalIPs`. Each one needs an owner and a reason. A Service created for a test and never deleted is the most common accidental exposure. The fix is to change the type back to `ClusterIP`, which releases the node port.

Services that must stay published can be narrowed. With `externalTrafficPolicy: Local`, a node forwards traffic only to its own pods and keeps the client address. It drops the traffic when it has no ready pod. With `loadBalancerSourceRanges`, the platform restricts a load balancer to the listed client ranges. The field does nothing for a `NodePort` Service, and it works only where the platform enforces it.

An Ingress controller replaces many published Services with one entry point and keeps the applications at `ClusterIP`. An Ingress object does nothing without a controller. An Ingress also does not remove the older node ports, which still bypass it. A complete audit checks Service types, `externalIPs`, Ingress objects and host-network pods.

Key facts to remember:

- `NodePort` opens the port on every node, not only on nodes with pods.
- A `LoadBalancer` Service also has a node port and a cluster address.
- `externalTrafficPolicy: Local` keeps the client address and drops traffic on nodes without ready pods.
- The platform reads `loadBalancerSourceRanges`, and only for `LoadBalancer` Services.
- An Ingress controller enforces an Ingress, and the controller needs one published Service of its own.

<!-- astrona:playground:destroy -->
