---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Close An Accidental NodePort And Keep One Local Solution

Use a host shell with the private kubeconfig for this independent kind environment.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-01" || exit 1
node_name="astro-ats-033-lab-030-02-01-control-plane"
worker_name="astro-ats-033-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers.

Inspect the exposed Services first:

```sh
kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,NODEPORT:.spec.ports[*].nodePort
```

Save this as `service-probe-debug.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-debug
  namespace: starfleet-033-030-02-01
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
kubectl apply -f service-probe-debug.yaml
```

Save this as `service-probe-public.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-public
  namespace: starfleet-033-030-02-01
spec:
  type: NodePort
  externalTrafficPolicy: Local
  selector:
    app: probe
    release: probe
  ports:
  - name: http
    port: 80
    targetPort: http
    nodePort: 30081
```

Apply it:

```sh
kubectl apply -f service-probe-public.yaml
```

Then check the result. The request from `drifter` is expected to fail, so run it on its own:

```sh
kubectl get services -n starfleet-033-030-02-01
kubectl -n starfleet-033-030-02-01 exec shuttle -- wget -qO- -T 3 http://probe-debug.starfleet-033-030-02-01/
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n outpost-033-030-02-01 exec drifter -- wget -qO- -T 3 "http://$NODE_IP:30080/"
```

The first request prints a line that starts with `version=v1`. The request to port 30080 fails, because no Service opens that node port any more.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-02-01`.

## Common pitfalls

> [!WARNING]
> - **Deleting the wrong Service.** The `probe` Service is the internal path that other pods use. Change only `probe-debug` and `probe-public`.
> - **Keeping `nodePort` in a `ClusterIP` Service.** The API server rejects a node port on a `ClusterIP` Service, or the field remains from the old object. Check the result with `kubectl get service`.
> - **Testing the denial from the node.** Test from a pod, which sends traffic the way a real client does.
