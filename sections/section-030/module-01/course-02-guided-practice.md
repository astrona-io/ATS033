---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Guided Practice: Bind A Host-Network Service To Loopback

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-030-01" || exit 1
node_name="astro-ats-033-playground-030-01-control-plane"
worker_name="astro-ats-033-playground-030-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create node-local-server on the control-plane container network, listening on 127.0.0.1:19090 only. A request from that server container to loopback must succeed. A request from the ordinary shuttle Pod to the node InternalIP on port 19090 must fail specifically with Connection refused. Keep the private node service and cluster available. This practices listener scope, not a host firewall implementation.

Save this as `pod-node-local-server.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-local-server
  namespace: starfleet
spec:
  restartPolicy: Never
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
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  nodeSelector:
    kubernetes.io/hostname: astro-ats-033-playground-030-01-control-plane
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
```

Apply the scoped correction:

```sh
kubectl apply -f pod-node-local-server.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
kubectl -n starfleet exec node-local-server -- python -c 'import urllib.request; print(urllib.request.urlopen('"'"'http://127.0.0.1:19090/'"'"',timeout=3).status)'
```

Keep a node-local management-style service reachable locally while closing its node-address listener. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.


## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
