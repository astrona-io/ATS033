# Narrowing NodePorts And Load Balancers

Some Services must stay published. A public web application needs a way in. The goal then changes from removing the exposure to narrowing it: fewer clients, fewer paths, and no surprises about which source address the application sees.

Two Service fields do this work, `externalTrafficPolicy` and `loadBalancerSourceRanges`. On this page, you see what each field changes, which component acts on it, and what happens when it is set wrongly.

## What externalTrafficPolicy decides

The field `externalTrafficPolicy` tells `kube-proxy` what to do with traffic that arrives at a node port or at a load balancer address. It has two values, and they treat the client address in different ways.

With `Cluster`, the default, a node accepts the packet and may forward it to a pod on any node. To make the reply come back the same way, the node replaces the source address of the packet with its own address. This is called source network address translation (SNAT). The application sees the node as the client, and the real client address is lost. Rules in the application or in a NetworkPolicy cannot use that address.

With `Local`, a node forwards the packet only to pods on the same node, and it keeps the original client address. A node with no ready pod of the Service drops the packet. On `LoadBalancer` Services, the cluster also allocates a second port, `healthCheckNodePort`. A load balancer calls this port to learn which nodes have pods, and it sends traffic only to those nodes.

![Diagram: under externalTrafficPolicy Cluster both nodes forward the request and replace the client address, under Local the node with a probe pod forwards and keeps the client address while the node without a pod drops the request](images/external-traffic-policy.svg)

The drawing compares the two values on the two nodes of the playground. The `Local` setting narrows the exposure in two ways. Only a node that runs a pod can answer a request. And the application sees the true client address, which makes logging and address-based controls correct.

## What loadBalancerSourceRanges decides

The first field decides which nodes forward the traffic. The second field decides which clients may send it at all.

The field `loadBalancerSourceRanges` is a list of client address ranges in CIDR notation, for example `203.0.113.0/24`. CIDR (Classless Inter-Domain Routing) notation writes a range as a start address and the number of fixed bits. The field applies to Services of type `LoadBalancer`. The cloud provider integration reads the list and configures the external load balancer, or its firewall, to accept only those ranges. On some setups, `kube-proxy` also adds matching rules on the nodes.

A request from an address outside the list is dropped. If the field is empty, the load balancer accepts clients from any address. This is the most common reason why a "private" application is reachable from the internet.

![Diagram: a client in 203.0.113.0/24 passes the load balancer and reaches the node port, while a client from any other address is dropped at the load balancer](images/load-balancer-source-ranges.svg)

The drawing shows the filter at the load balancer: one client range passes, every other address is dropped before it reaches a node.

Which component enforces the list depends on the platform. So the field is only a request until the platform acts on it. Read the documentation of your cloud provider before you rely on it.

## Create the Service and see the effect on one node

Now try both fields in the playground. It already has the `probe-edge` Service of type `LoadBalancer`. Select the environment and read the fields of that Service:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-030-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-030-02" || exit 1
node_name="astro-ats-033-playground-030-02-control-plane"
worker_name="astro-ats-033-playground-030-02-worker"
kubectl -n starfleet get service probe-edge -o jsonpath='{.spec.externalTrafficPolicy}{"\n"}{.spec.loadBalancerSourceRanges}{"\n"}{.spec.ports[0].nodePort}{"\n"}{.status.loadBalancer}{"\n"}'
```

The output has four lines:

- The first line is `Cluster`. Nobody set the field, so the API server filled in the default.
- The second line is empty, so the load balancer would accept any client range.
- The third line is the node port that the API server allocated for the load balancer to use.
- The last line is empty. `kind` runs no cloud provider integration, so the `EXTERNAL-IP` stays `<pending>`.

Save this as `service-probe-edge.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-edge
  namespace: starfleet
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  loadBalancerSourceRanges:
  - 203.0.113.0/24
  selector:
    app: probe
    release: probe
  ports:
  - name: http
    port: 80
    targetPort: http
```

The range `203.0.113.0/24` is a documentation range. It stands here for the network of the clients. Apply it:

```sh
kubectl apply -f service-probe-edge.yaml
```

Then check the result. Read the node port, then send a request to it on each node. Run the requests on their own, because one of them is expected to fail:

```sh
EDGE_PORT="$(kubectl -n starfleet get service probe-edge -o jsonpath='{.spec.ports[0].nodePort}')"
CONTROL_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
WORKER_IP="$(kubectl get node "$worker_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$WORKER_IP:$EDGE_PORT/"
kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$CONTROL_IP:$EDGE_PORT/"
```

The `probe` pods run on the worker node, so the request to the worker address prints a line that starts with `version=v1`. The control-plane node has no ready `probe` pod. Under `Local`, its `kube-proxy` rules do not forward the request, and the second request times out. Before the change, both requests worked.

## Why the policy matters for security

Narrowing helps, but it has limits. `loadBalancerSourceRanges` does nothing for a Service of type `NodePort`, because there is no load balancer to read it. For a node port, the filter must be a firewall or a cloud security group on the nodes. The `Local` policy removes a forwarding hop, but it adds no protection by itself. A node that has a pod still accepts any client that reaches it.

A second risk is a wrong change. After you set `Local`, a rolling update can leave a node without a ready pod. That node then drops traffic, and a load balancer that does not use the health check port still sends traffic to it. Plan how the pods spread over the nodes together with the policy.

You now know the two fields that narrow a published Service, and which component acts on each. The question still open is how to publish many applications without opening a port for each of them.

## Common pitfalls

> [!WARNING]
> - **Setting `loadBalancerSourceRanges` on a `NodePort` Service.** Only a load balancer reads it. Filter node ports with a firewall.
> - **Assuming the load balancer enforces it everywhere.** The platform integration enforces the field. In `kind`, nothing does.
> - **Using `Local` without pods on the receiving nodes.** A node without a ready pod drops the traffic.
> - **Reading the client address as proof of identity.** With `Cluster`, the application sees the node address. With `Local`, it sees the client address, but a client in the same network can still choose that address.
