---
exam_objectives:
- Minimize external access to the network
---
# Bind A Host-Network Service To Loopback Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-01" || exit 1
node_name="astro-ats-033-lab-030-01-01-control-plane"
worker_name="astro-ats-033-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Step 1: Find the listener

A pod with `hostNetwork: true` shares the network of its node. Its listeners are listeners of the node, so `ss` inside the node container shows them. Read the node's InternalIP first, because the test requests use it:

```sh
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
echo "$NODE_IP"
podman exec "$node_name" ss -tlnp 'sport = :19090'
```

In the live run the address was `10.89.0.53`. Your address can differ. The `ss` output was:

```text
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      5            0.0.0.0:19090      0.0.0.0:*    users:(("python",pid=1685,fd=3))
```

The local address `0.0.0.0` is the wildcard address. The Python process accepts connections on every address of the node, so a request from `shuttle` to the node address works:

```sh
kubectl -n starfleet-033-030-01-01 exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19090/"
```

The request printed an HTML page that starts with `<title>Directory listing for /</title>`. The output is shortened here. The pod command shows the cause:

```sh
kubectl -n starfleet-033-030-01-01 get pod node-local-server -o jsonpath='{.spec.containers[0].command}'
```

```text
["python","-m","http.server","19090","--bind","0.0.0.0"]
```

## Step 2: Replace the pod with a loopback bind

The command of a running container cannot change, so the fix is a new pod with the same name. The only change is the value after `--bind`.

Save this as `pod-node-local-server.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-local-server
  namespace: starfleet-033-030-01-01
  labels:
    app: node-local-server
spec:
  restartPolicy: Never
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
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

Delete the old pod and apply the file:

```sh
kubectl -n starfleet-033-030-01-01 delete pod node-local-server
kubectl apply -f pod-node-local-server.yaml
```

```text
pod "node-local-server" deleted from starfleet-033-030-01-01 namespace
pod/node-local-server created
```

The old pod must be gone first. Both pods share the network of the node, so the new server could not open port 19090 while the old one still held it.

## Step 3: Check the result

Wait for the pod, then read the listener again and send the two requests. The request from `shuttle` is expected to fail, so run it on its own:

```sh
kubectl -n starfleet-033-030-01-01 wait --for=condition=Ready pod/node-local-server --timeout=180s
podman exec "$node_name" ss -tlnp 'sport = :19090'
podman exec "$node_name" curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19090/
kubectl -n starfleet-033-030-01-01 exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19090/"
```

The live run printed:

```text
pod/node-local-server condition met
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      5          127.0.0.1:19090      0.0.0.0:*    users:(("python",pid=1848,fd=3))
200
wget: can't connect to remote host (10.89.0.53): Connection refused
command terminated with exit code 1
```

The listener now has the local address `127.0.0.1`. The `curl` request runs inside the node container, where loopback is the node's loopback, and it gets status 200. The request from `shuttle` reaches the node, finds no listener on the node address and gets `Connection refused` at once. A refused connection points to the bind address, not to a firewall. A firewall that drops packets gives a timeout instead.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-01-01`.

## Common pitfalls

> [!WARNING]
> - **Applying the new pod while the old one runs.** `kubectl apply` cannot change the command of an existing pod. Delete the pod first, or use `kubectl replace --force -f pod-node-local-server.yaml`.
> - **Testing only from inside the node.** A request on loopback works with both bind addresses. Only a request from another host or pod shows whether the node address is closed.
> - **Reading a timeout as success.** The task asks for `Connection refused`. A timeout means something else blocks the request, and the listener may still be wide.
