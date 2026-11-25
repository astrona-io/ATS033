---
exam_objectives:
- Minimize external access to the network
---
# Answer A NodePort Only On Nodes With Endpoints Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-02" || exit 1
node_name="astro-ats-033-lab-030-02-02-control-plane"
worker_name="astro-ats-033-lab-030-02-02-worker"
```

Keep this connection selected.

## Step 1: Look at the pods and the Service

The field `externalTrafficPolicy` tells kube-proxy where to send traffic that arrives on a node port. With `Cluster`, every node forwards the traffic to any ready pod of the Service. With `Local`, a node forwards only to pods on the same node and drops the traffic when it has none. Check where the pods run and which policy the Service uses:

```sh
kubectl -n starfleet-033-030-02-02 get pods -o wide
kubectl -n starfleet-033-030-02-02 get service probe-public -o jsonpath='{.spec.type} {.spec.externalTrafficPolicy} {.spec.ports[0].nodePort}{"\n"}'
```

The live run printed the output below. The `NOMINATED NODE` and `READINESS GATES` columns are cut here:

```text
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE
probe-744874ff8d-2csq7   1/1     Running   0          2s    10.244.1.3   astro-ats-033-lab-030-02-02-worker
probe-744874ff8d-khx8t   1/1     Running   0          2s    10.244.1.2   astro-ats-033-lab-030-02-02-worker
NodePort Cluster 30081
```

Both pods run on the worker node, and the policy is `Cluster`.

## Step 2: Test both node addresses

Read the two node addresses and send a request from `drifter` to port 30081 on each of them:

```sh
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
WORKER_IP="$(kubectl get node "$worker_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n outpost-033-030-02-02 exec drifter -- wget -q -T 3 -O- "http://$WORKER_IP:30081/"
kubectl -n outpost-033-030-02-02 exec drifter -- wget -q -T 3 -O- "http://$NODE_IP:30081/"
```

```text
version=v1 host=probe-744874ff8d-khx8t
version=v1 host=probe-744874ff8d-2csq7
```

The control-plane node answers too. kube-proxy on that node forwards the request to a pod on the worker. It also replaces the client's source address with its own, so the pod cannot see who really sent the request.

## Step 3: Set the policy to Local

Save this as `service-probe-public.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-public
  namespace: starfleet-033-030-02-02
spec:
  type: NodePort
  externalTrafficPolicy: Local
  selector:
    app: probe
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

```text
service/probe-public configured
```

Then check the result:

```sh
kubectl -n starfleet-033-030-02-02 get service probe-public -o jsonpath='{.spec.type} {.spec.externalTrafficPolicy} {.spec.ports[0].nodePort}{"\n"}'
kubectl -n outpost-033-030-02-02 exec drifter -- wget -q -T 3 -O- "http://$WORKER_IP:30081/"
kubectl -n outpost-033-030-02-02 exec drifter -- wget -q -T 3 -O- "http://$NODE_IP:30081/"
```

```text
NodePort Local 30081
version=v1 host=probe-744874ff8d-khx8t
wget: download timed out
command terminated with exit code 1
```

The worker node still answers, because it runs `probe` pods. The control-plane node has no local `probe` pod, so kube-proxy on that node drops the traffic, and the client waits until its timeout. As a side effect, the pods now see the real source address of external clients, because no node forwards and rewrites the traffic.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-02-02`.

## Common pitfalls

> [!WARNING]
> - **Testing from a pod on the same node.** kube-proxy handles traffic from a pod to a node address on its own node as internal traffic. A pod on the control-plane node still gets an answer from the control-plane address. Test from another node, as `drifter` does.
> - **Expecting `Local` to close the port.** The node port stays open on every node. Nodes without a local pod drop the traffic, so a client sees a timeout, not `Connection refused`.
> - **Losing all endpoints on a node.** With `Local`, a node whose pods all go away stops answering. Spread the pods or use a load balancer that checks node health.
