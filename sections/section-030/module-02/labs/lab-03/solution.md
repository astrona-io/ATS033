---
exam_objectives:
- Minimize external access to the network
---
# Audit And Close Unapproved Service Exposure Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-03" || exit 1
node_name="astro-ats-033-lab-030-02-03-control-plane"
worker_name="astro-ats-033-lab-030-02-03-worker"
```

Keep this connection selected.

## Step 1: Audit the Services

A Service can open a way into the cluster in three places. The type `NodePort` opens a port on every node. The field `externalIPs` makes kube-proxy accept traffic for extra addresses that Kubernetes does not manage. A pod with `hostNetwork: true` shares the network of its node, so any port it opens is a port of the node. List every Service with its type, external addresses and node ports:

```sh
kubectl get services -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IPS:.spec.externalIPs,NODE-PORTS:.spec.ports[*].nodePort'
```

```text
NAMESPACE                 NAME           TYPE        EXTERNAL-IPS     NODE-PORTS
default                   kubernetes     ClusterIP   <none>           <none>
kube-system               kube-dns       ClusterIP   <none>           <none>
outpost-033-030-02-03     beacon-debug   NodePort    <none>           30090
starfleet-033-030-02-03   probe-legacy   ClusterIP   [203.0.113.10]   <none>
starfleet-033-030-02-03   probe-public   NodePort    <none>           30081
```

Two Services need work. `probe-legacy` has the type `ClusterIP` but still lists `203.0.113.10`, so its type alone hides the exposure. `beacon-debug` opens node port 30090.

## Step 2: Audit the host-network pods

Next, list the pods that use the host network:

```sh
kubectl get pods -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOST-NETWORK:.spec.hostNetwork,NODE:.spec.nodeName' --field-selector spec.hostNetwork=true
```

```text
NAMESPACE               NAME                                                                HOST-NETWORK   NODE
kube-system             etcd-astro-ats-033-lab-030-02-03-control-plane                      true           astro-ats-033-lab-030-02-03-control-plane
kube-system             kindnet-67jg9                                                       true           astro-ats-033-lab-030-02-03-worker
kube-system             kindnet-zqbpz                                                       true           astro-ats-033-lab-030-02-03-control-plane
kube-system             kube-apiserver-astro-ats-033-lab-030-02-03-control-plane            true           astro-ats-033-lab-030-02-03-control-plane
kube-system             kube-controller-manager-astro-ats-033-lab-030-02-03-control-plane   true           astro-ats-033-lab-030-02-03-control-plane
kube-system             kube-proxy-kxbd6                                                    true           astro-ats-033-lab-030-02-03-worker
kube-system             kube-proxy-w8h7w                                                    true           astro-ats-033-lab-030-02-03-control-plane
kube-system             kube-scheduler-astro-ats-033-lab-030-02-03-control-plane            true           astro-ats-033-lab-030-02-03-control-plane
outpost-033-030-02-03   relay                                                               true           astro-ats-033-lab-030-02-03-worker
```

The control-plane components, kindnet and kube-proxy need the host network to do their job. The pod `relay` in `outpost-033-030-02-03` is the only workload pod on the list.

## Step 3: Prove that each entry answers

Before you change anything, test each entry from `shuttle`, so that you can compare the result later. Read the worker address first:

```sh
WORKER_IP="$(kubectl get node "$worker_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- http://203.0.113.10/
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- "http://$WORKER_IP:30090/"
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- "http://$WORKER_IP:18080/"
```

The live run printed the output below. The HTML page from port 18080 is shortened here to its title:

```text
version=v1 host=probe-5759f97554-pbplz
version=beacon host=beacon
<title>Directory listing for /</title>
```

All three entries answer. The last one is the worst: `relay` lists the files of its container to any caller that reaches the worker node.

## Step 4: Remove externalIPs from probe-legacy

The field `externalIPs` can be removed only by applying the Service without it. Save this as `service-probe-legacy.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe-legacy
  namespace: starfleet-033-030-02-03
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
kubectl apply -f service-probe-legacy.yaml
```

```text
service/probe-legacy configured
```

## Step 5: Change beacon-debug to ClusterIP

Save this as `service-beacon-debug.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: beacon-debug
  namespace: outpost-033-030-02-03
spec:
  type: ClusterIP
  selector:
    app: beacon
  ports:
  - name: http
    port: 80
    targetPort: http
```

Apply it:

```sh
kubectl apply -f service-beacon-debug.yaml
```

```text
service/beacon-debug configured
```

## Step 6: Delete the relay pod

`relay` is a bare pod with no controller, so deleting it removes it for good:

```sh
kubectl -n outpost-033-030-02-03 delete pod relay
```

```text
pod "relay" deleted from outpost-033-030-02-03 namespace
```

## Step 7: Check the result

Run the audit and the requests again:

```sh
kubectl get services -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IPS:.spec.externalIPs,NODE-PORTS:.spec.ports[*].nodePort'
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- http://203.0.113.10/
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- "http://$WORKER_IP:30090/"
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- "http://$WORKER_IP:18080/"
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- "http://$WORKER_IP:30081/"
kubectl -n starfleet-033-030-02-03 exec shuttle -- wget -q -T 3 -O- http://probe-legacy/
```

```text
NAMESPACE                 NAME           TYPE        EXTERNAL-IPS   NODE-PORTS
default                   kubernetes     ClusterIP   <none>         <none>
kube-system               kube-dns       ClusterIP   <none>         <none>
outpost-033-030-02-03     beacon-debug   ClusterIP   <none>         <none>
starfleet-033-030-02-03   probe-legacy   ClusterIP   <none>         <none>
starfleet-033-030-02-03   probe-public   NodePort    <none>         30081
wget: download timed out
command terminated with exit code 1
wget: can't connect to remote host (10.89.0.132): Connection refused
command terminated with exit code 1
wget: can't connect to remote host (10.89.0.132): Connection refused
command terminated with exit code 1
version=v1 host=probe-5759f97554-8jw5b
version=v1 host=probe-5759f97554-8jw5b
```

kube-proxy no longer forwards traffic for `203.0.113.10`, so nothing answers that address and the request times out. kube-proxy also removed the rule for port 30090, and no process on the worker listens on 18080 any more, so the worker refuses both. The approved entry on port 30081 and the in-cluster name `probe-legacy` still work.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-02-03`.

## Common pitfalls

> [!WARNING]
> - **Trusting the type column.** A Service of type `ClusterIP` with `externalIPs` is still reachable from outside. Check the field itself.
> - **Removing the field with `kubectl edit` but keeping a stale manifest.** The next `kubectl apply` of the old file brings `externalIPs` back. Fix the file that the team applies.
> - **Deleting a controlled pod.** A pod owned by a Deployment or DaemonSet comes back at once. Change or delete the controller instead.
> - **Listing only pods with `kubectl get pods`.** The default columns do not show `hostNetwork`. Use a field selector or custom columns.
