---
exam_objectives:
- Minimize external access to the network
---
# Default-Deny Ingress With One Allowed Client Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-03" || exit 1
```

Keep this connection selected.

## Step 1: Test the open namespace

A NetworkPolicy is a Kubernetes object that limits the traffic to or from a group of pods. The network plugin of the cluster (here kindnet) reads the policies and enforces them. Without any policy, every pod accepts traffic from every other pod. Read the pod IP of `beacon` and send four requests:

```sh
BEACON_IP="$(kubectl -n starfleet-033-030-01-03 get pod beacon -o jsonpath='{.status.podIP}')"
kubectl -n starfleet-033-030-01-03 exec shuttle -- wget -q -T 3 -O- http://probe/
kubectl -n outpost-033-030-01-03 exec drifter -- wget -q -T 3 -O- http://probe.starfleet-033-030-01-03.svc.cluster.local/
kubectl -n starfleet-033-030-01-03 exec shuttle -- wget -q -T 3 -O- "http://$BEACON_IP:8080/"
kubectl -n outpost-033-030-01-03 exec drifter -- wget -q -T 3 -O- "http://$BEACON_IP:8080/"
```

In the live run all four requests worked. The pod names in your output differ:

```text
version=v1 host=probe-66bc96f6cb-k9d4g
version=v1 host=probe-66bc96f6cb-z4lxd
version=beacon host=beacon
version=beacon host=beacon
```

`drifter` lives in another namespace and still reaches both servers. The two policies below close that gap.

## Step 2: Deny all ingress

A policy with an empty `podSelector` (`{}`) selects every pod in its namespace. `policyTypes: [Ingress]` with no `ingress` list allows no incoming traffic at all.

Save this as `networkpolicy-default-deny-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: starfleet-033-030-01-03
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Apply it:

```sh
kubectl apply -f networkpolicy-default-deny-ingress.yaml
```

Then check the result with the request that must keep working:

```sh
kubectl -n starfleet-033-030-01-03 exec shuttle -- wget -q -T 3 -O- http://probe/
```

```text
wget: download timed out
command terminated with exit code 1
```

The default deny also blocks `shuttle`. kindnet drops the packets without an answer, so the client waits until its 3-second timeout. An allow policy must open the one path the task needs.

## Step 3: Allow shuttle to reach probe

NetworkPolicies add up. A pod that several policies select accepts the traffic that any one of them allows. The second policy selects the `probe` pods and allows traffic from pods with the label `app: shuttle` in the same namespace on TCP port 8080. The port is the container port, not the Service port 80, because kindnet checks the packet after the Service address was translated to the pod address.

Save this as `networkpolicy-probe-allow-shuttle.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: probe-allow-shuttle
  namespace: starfleet-033-030-01-03
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
kubectl apply -f networkpolicy-probe-allow-shuttle.yaml
```

Then check the result:

```sh
kubectl -n starfleet-033-030-01-03 describe networkpolicy probe-allow-shuttle
```

```text
Name:         probe-allow-shuttle
Namespace:    starfleet-033-030-01-03
Created on:   2026-11-17 22:57:07 +0100 CET
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     app=probe
  Allowing ingress traffic:
    To Port: 8080/TCP
    From:
      PodSelector: app=shuttle
  Not affecting egress traffic
  Policy Types: Ingress
```

A `podSelector` under `from` without a `namespaceSelector` matches pods in the policy's own namespace only. A pod with the label `app: shuttle` in `outpost-033-030-01-03` would not match.

## Step 4: Send the four requests again

Run the same four requests from the first step:

```sh
kubectl -n starfleet-033-030-01-03 exec shuttle -- wget -q -T 3 -O- http://probe/
kubectl -n outpost-033-030-01-03 exec drifter -- wget -q -T 3 -O- http://probe.starfleet-033-030-01-03.svc.cluster.local/
kubectl -n starfleet-033-030-01-03 exec shuttle -- wget -q -T 3 -O- "http://$BEACON_IP:8080/"
kubectl -n outpost-033-030-01-03 exec drifter -- wget -q -T 3 -O- "http://$BEACON_IP:8080/"
```

```text
version=v1 host=probe-66bc96f6cb-z4lxd
wget: download timed out
command terminated with exit code 1
wget: download timed out
command terminated with exit code 1
wget: download timed out
command terminated with exit code 1
```

Only the first request works. `drifter` cannot reach `probe`, and no client reaches `beacon`, because only the default deny selects `beacon`.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-01-03`.

## Common pitfalls

> [!WARNING]
> - **Allowing the Service port.** The allow rule must name port 8080, the port of the pod. A rule for port 80 matches nothing, and `shuttle` keeps timing out.
> - **Forgetting `policyTypes`.** Without `Ingress` in `policyTypes` and without an `ingress` list, a policy does not restrict ingress for the selected pods.
> - **Expecting a namespace-wide rule from a pod selector.** A `podSelector` in `from` matches only the policy's namespace. Use a `namespaceSelector` to allow pods from another namespace.
