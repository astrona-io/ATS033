---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Guided Practice: Close A NodePort And Narrow A LoadBalancer

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-030-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-030-02" || exit 1
node_name="astro-ats-033-playground-030-02-control-plane"
worker_name="astro-ats-033-playground-030-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Starting state

The `starfleet` namespace runs the `probe` Deployment with two replicas and the `probe` Service of type `ClusterIP`. `probe-admin` is of type `NodePort` on node port 30090. `probe-edge` is of type `LoadBalancer`. The `shuttle` pod in `starfleet` and the `drifter` pod in `outpost` run BusyBox.

## Task

Make `probe-admin` a `ClusterIP` Service, so no node port remains. Make `probe-edge` accept only the client range `203.0.113.0/24` and set its `externalTrafficPolicy` to `Local`.

## Inspect, change and verify

Inspect the exposed Services:

```sh
kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,NODEPORT:.spec.ports[*].nodePort
```

Save this as `service-probe-admin.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-admin
  namespace: starfleet
spec:
  type: ClusterIP
  selector:
    app: probe
    release: probe
  ports:
  - name: http
    port: 80
    targetPort: http
```

Apply it:

```sh
kubectl apply -f service-probe-admin.yaml
```

Save this as `service-probe-edge.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-edge
  namespace: starfleet
spec:
  type: LoadBalancer
  selector:
    app: probe
    release: probe
  ports:
  - name: http
    port: 80
    targetPort: http
  externalTrafficPolicy: Local
  loadBalancerSourceRanges:
  - 203.0.113.0/24
```

Apply it:

```sh
kubectl apply -f service-probe-edge.yaml
```

Then check the result:

```sh
kubectl -n starfleet get services probe-admin probe-edge
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$NODE_IP:30090/"
```

The request to port 30090 is expected to fail.

## Common pitfalls

> [!WARNING]
> - **Expecting an external address in `kind`.** No load balancer controller runs here, so the `EXTERNAL-IP` of `probe-edge` stays `<pending>`.
> - **Deleting the `probe` Service.** Change only `probe-admin` and `probe-edge`.
