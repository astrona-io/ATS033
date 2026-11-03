---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Reduce The External Exposure Of A Cluster Solution

Use a host shell with the private kubeconfig for this independent kind environment.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-capstone-01" || exit 1
node_name="astro-ats-033-lab-030-capstone-01-control-plane"
worker_name="astro-ats-033-lab-030-capstone-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers.

Start with an inventory of everything that listens or publishes access. Run the three commands and note one finding from each:

```sh
run_on_node() { podman exec "$node_name" "$@"; }
run_on_node ss -tln
kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,NODEPORT:.spec.ports[*].nodePort
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

The `ss` output shows `node-local-server` on all interfaces at port 19090. The Service list shows two Services of type `NodePort`. The last request returns status 200.

The command of a pod cannot change in place, so delete the pod and create it again with the loopback bind address. Save this as `pod-node-local-server.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-local-server
  namespace: starfleet
spec:
  restartPolicy: Never
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  nodeSelector:
    kubernetes.io/hostname: astro-ats-033-lab-030-capstone-01-control-plane
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: web
    image: docker.io/library/python:3.13-alpine
    command:
    - python
    - -m
    - http.server
    - '19090'
    - --bind
    - 127.0.0.1
```

Delete the old pod and apply the new one:

```sh
kubectl -n starfleet delete pod node-local-server --wait=true
kubectl apply -f pod-node-local-server.yaml
```

Save this as `service-probe-debug.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-debug
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

Save this as `service-probe-public.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-public
  namespace: starfleet
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

Apply both:

```sh
kubectl apply -f service-probe-debug.yaml
kubectl apply -f service-probe-public.yaml
```

Close the kubelet API on the worker node and restart the kubelet:

```sh
podman exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" systemctl restart kubelet
```

Then check the result. The requests from the pods are expected to fail, so run each on its own:

```sh
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19090/"
kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$NODE_IP:30080/"
kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe-debug.starfleet/
kubectl get nodes
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

The first two requests fail, the third prints a line that starts with `version=v1`, the worker node is `Ready` and the last request returns status 401.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-capstone-01`.

## Common pitfalls

> [!WARNING]
> - **Patching the pod command.** The command of a pod cannot change after creation. Delete and create the pod.
> - **Fixing only the first finding.** The grader checks all four results.
> - **Editing the control-plane node.** Change only the worker container for the kubelet.
