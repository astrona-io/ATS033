---
exam_objectives:
- Minimize external access to the network
---
# Close An Accidental NodePort Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-01" || exit 1
node_name="astro-ats-033-lab-030-02-01-control-plane"
worker_name="astro-ats-033-lab-030-02-01-worker"
```

Keep this connection selected.

## Step 1: Find the open node port

A Service of type `NodePort` makes kube-proxy open the same port on every node and forward it to the Service's pods. List every NodePort Service in the cluster:

```sh
kubectl get services -A --field-selector spec.type=NodePort
```

```text
NAMESPACE                 NAME          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
starfleet-033-030-02-01   probe-debug   NodePort   10.96.148.213   <none>        80:30080/TCP   1s
```

`80:30080/TCP` means Service port 80 inside the cluster and node port 30080 on every node. Read both node addresses and send a request from `drifter` to each of them:

```sh
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
WORKER_IP="$(kubectl get node "$worker_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n outpost-033-030-02-01 exec drifter -- wget -q -T 3 -O- "http://$NODE_IP:30080/"
kubectl -n outpost-033-030-02-01 exec drifter -- wget -q -T 3 -O- "http://$WORKER_IP:30080/"
```

```text
version=v1 host=probe-5759f97554-ddn85
version=v1 host=probe-5759f97554-52xft
```

Both node addresses answer, including the control-plane node. Your pod names differ.

## Step 2: Change the Service type

A ClusterIP Service gets only a virtual address inside the cluster. kube-proxy does not open a node port for it. Keep the name, the selector and the ports, and change only the type.

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
  ports:
  - name: http
    port: 80
    targetPort: http
```

Apply it:

```sh
kubectl apply -f service-probe-debug.yaml
```

```text
service/probe-debug configured
```

Then check the result:

```sh
kubectl -n starfleet-033-030-02-01 get service probe-debug -o jsonpath='{.spec.type} {.spec.ports}{"\n"}'
```

```text
ClusterIP [{"name":"http","port":80,"protocol":"TCP","targetPort":"http"}]
```

The port list has no `nodePort` field any more. `kubectl apply` removed it, because the new manifest no longer sets it, and a ClusterIP Service cannot have a node port.

## Step 3: Test both paths

Send the two requests from `drifter` again, and one request from `shuttle` to the Service name:

```sh
kubectl -n outpost-033-030-02-01 exec drifter -- wget -q -T 3 -O- "http://$NODE_IP:30080/"
kubectl -n outpost-033-030-02-01 exec drifter -- wget -q -T 3 -O- "http://$WORKER_IP:30080/"
kubectl -n starfleet-033-030-02-01 exec shuttle -- wget -q -T 3 -O- http://probe-debug/
```

The live run printed the output below. The node addresses were `10.89.0.108` and `10.89.0.107`:

```text
wget: can't connect to remote host (10.89.0.108): Connection refused
command terminated with exit code 1
wget: can't connect to remote host (10.89.0.107): Connection refused
command terminated with exit code 1
version=v1 host=probe-5759f97554-ddn85
```

kube-proxy removed its rules for port 30080, and no process listens on that port, so both nodes refuse the connection. Inside the cluster, `probe-debug` still works through its ClusterIP.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-02-01`.

## Common pitfalls

> [!WARNING]
> - **Keeping `nodePort` in the manifest.** A manifest with `type: ClusterIP` and a `nodePort` value is not valid. Leave the field out, as above.
> - **Testing only from the Service's namespace.** A request to the ClusterIP from `shuttle` says nothing about the node port. Test the node addresses as well.
> - **Deleting the Service.** The task keeps `probe-debug` for clients inside the cluster. Deleting it breaks them.
