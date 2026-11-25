# NetworkPolicy For Pod Traffic

By default, every pod in a Kubernetes cluster can send traffic to every other pod, in any namespace. One compromised pod can then scan and attack the whole pod network. The host firewall of a node does not help here, because most pod-to-pod traffic never arrives at the `INPUT` chain of a node.

Kubernetes controls this traffic with a NetworkPolicy. On this page, you write a policy that denies all incoming traffic in a namespace, add one allow rule, and test both from two client pods.

## What a NetworkPolicy is and who enforces it

A **NetworkPolicy** is a namespaced Kubernetes object that selects pods and lists the traffic those pods may receive (ingress) or send (egress). The API server only stores the object. The **CNI plugin** (Container Network Interface plugin, the component that sets up pod networking) enforces it on the nodes.

If the plugin does not support NetworkPolicy, the objects exist and have no effect. This is the first thing to check when a policy seems to do nothing.

Four rules of the model matter for the exam:

- A pod that no NetworkPolicy selects accepts all traffic. Once any policy with `Ingress` in `policyTypes` selects a pod, that pod accepts only the ingress that some policy allows.
- Policies only add allowed traffic. There is no deny rule, and several policies on the same pod combine as a union: the pod accepts everything that any of them allows.
- A rule's `from` can use `podSelector`, `namespaceSelector` and `ipBlock`. A `podSelector` alone matches pods in the policy's own namespace.
- The `ports` field names the port on the destination pod (the container port), not the port of a Service in front of it.

An empty `podSelector: {}` selects every pod in the namespace. A policy with that selector and no ingress rules is the standard **default deny**.

## The traffic before any policy

Start with the open network, so you can see what a policy changes. Select the environment. The `probe` pods listen on container port 8080, and the `probe` Service maps port 80 to it. Send a request from each client pod: `shuttle` is in `starfleet`, and `drifter` is in `outpost`.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-030-01" || exit 1
kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe.starfleet.svc.cluster.local
kubectl -n outpost exec drifter -- wget -qO- -T 3 http://probe.starfleet.svc.cluster.local
```

Both requests print a line that starts with `version=v1`. Without a policy, the client in another namespace reaches the `probe` pods as easily as the client in the same namespace.

## Deny all ingress

The first step is to close the namespace. This policy selects every pod in `starfleet` and allows no incoming traffic.

Save this as `networkpolicy-default-deny-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Apply it:

```sh
kubectl apply -f networkpolicy-default-deny-ingress.yaml
```

Then check the result. Run the two requests again. Each one is expected to fail, so run them on their own:

```sh
kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe.starfleet.svc.cluster.local
kubectl -n outpost exec drifter -- wget -qO- -T 3 http://probe.starfleet.svc.cluster.local
```

If the CNI plugin of the cluster enforces NetworkPolicy, both requests time out after three seconds, because the plugin drops the packets. A timeout, not a refusal, is the typical sign of a policy.

If both requests still print `version=v1`, the plugin of this cluster does not enforce the policy. In that case, nothing in the rest of this page changes the result.

## Allow one client to one port

A closed namespace is safe, but the `probe` pods still need their real client. The next policy selects the `probe` pods and allows ingress from pods labelled `app: shuttle` in the same namespace, on TCP port 8080. The `shuttle` pod has the label `app: shuttle`, and the `probe` pods have the label `app: probe`.

Save this as `networkpolicy-allow-shuttle-to-probe.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-shuttle-to-probe
  namespace: starfleet
spec:
  podSelector:
    matchLabels:
      app: probe
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: shuttle
    ports:
    - protocol: TCP
      port: 8080
```

Apply it:

```sh
kubectl apply -f networkpolicy-allow-shuttle-to-probe.yaml
```

Then check the result. The request from `shuttle` should work again, and the request from `drifter` should still fail:

```sh
kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe.starfleet.svc.cluster.local
kubectl -n outpost exec drifter -- wget -qO- -T 3 http://probe.starfleet.svc.cluster.local
kubectl -n starfleet get networkpolicy
```

The first command prints `version=v1` again. The allowed traffic to the `probe` pods is now the union of the deny-all policy (nothing) and the allow policy (this one client on port 8080). The second command still times out, and the policy list shows both objects.

![Diagram: in the starfleet namespace, the default-deny-ingress and allow-shuttle-to-probe policies let the shuttle pod reach the probe pods on TCP 8080, while the drifter pod in outpost is dropped](images/default-deny-allow-shuttle.svg)

The drawing shows the result. The policies admit one client and drop traffic from every other pod, including pods in other namespaces. The two policies together are the common pattern: deny everything, then allow each needed path by name.

## Cross-namespace sources and egress

The allow policy above only works for a client in the same namespace. To allow a client from another namespace, a `from` entry needs a `namespaceSelector`. The automatic label `kubernetes.io/metadata.name` holds the namespace name, so `namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: outpost}}` selects `outpost`.

A subtle point is the difference between one `from` item with both selectors and two separate items:

- One item with `namespaceSelector` and `podSelector` together means pods with that label in those namespaces (logical AND).
- Two separate items mean either source (logical OR).

![Diagram: one from item that holds both namespaceSelector and podSelector matches only pods that pass both, while two separate from items match a pod that passes either one](images/from-and-versus-or.svg)

The drawing shows how moving one dash changes the meaning. With two items, every pod in the selected namespaces gets in, and so does every pod with the label in the policy's own namespace.

Egress works the same way, with `policyTypes: [Egress]` and `to`. A default-deny egress policy also blocks DNS, so a policy that denies egress usually allows UDP and TCP port 53 to the cluster DNS pods.

Lastly, pods that use `hostNetwork: true` share the node's network, and most CNI plugins do not apply pod policies to them reliably. A host firewall or a bind address must protect that traffic.

You can now isolate pods from each other and test the result from two positions. What remains is the traffic that does not start inside the pod network: Services that publish a port on every node, and the ports of the control plane itself.

## Common pitfalls

> [!WARNING]
> - **Writing the Service port in `ports`.** A policy matches the container port of the destination pod. Port 80 on the Service does not match a pod that listens on 8080.
> - **Expecting a policy to work on any cluster.** The CNI plugin enforces it. If the plugin does not, the object has no effect.
> - **Using AND where you meant OR.** One `from` item with two selectors is AND. Two items are OR.
> - **Denying egress without allowing DNS.** Name lookups fail, and every Service name stops working.
> - **Forgetting namespaces.** A `podSelector` alone matches pods in the policy's own namespace only.
