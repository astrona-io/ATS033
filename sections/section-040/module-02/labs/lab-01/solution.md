---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Apply The RuntimeDefault seccomp Profile To Deployments Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-01" || exit 1
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-02-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context. Each kind node is a container, so `"$engine" exec "$cluster-control-plane" ...` runs a command on the control plane node.

## Check Every Pod

The `Seccomp:` line in `/proc/1/status` shows the seccomp mode of the main process of a container. `0` means no filter, and `2` means the container runtime installed a filter. This loop prints the line for every pod in the namespace:

```sh
for pod_name in $(kubectl -n starfleet-033-040-02-01 get pods -o name); do echo "$pod_name"; kubectl -n starfleet-033-040-02-01 exec "$pod_name" -- grep Seccomp: /proc/1/status; done
```

```text
pod/bridge-7c6f6b87df-4vfr4
Seccomp:	0
pod/bridge-7c6f6b87df-z822g
Seccomp:	0
pod/scout-6986786869-sq579
Seccomp:	0
```

No pod has a filter. `bridge` sets no profile, and the kubelet of this cluster does not set `seccompDefault`, so it treats a missing profile as `Unconfined`. You can confirm this on the node. The command prints nothing and exits with code 1, because the kubelet configuration file does not mention seccomp:

```sh
"$engine" exec "$cluster-control-plane" grep -i seccomp /var/lib/kubelet/config.yaml
```

## See Why scout Needs More Than A Profile

`scout` is a privileged container. Try adding only the profile to it, to see what happens. This JSON patch adds a pod-level security context with `RuntimeDefault`:

```sh
kubectl -n starfleet-033-040-02-01 patch deployment scout --type=json -p='[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"}}}]'
```

```text
deployment.apps/scout patched
```

Wait until the old pod is gone, about 30 seconds, then check the new pod:

```sh
kubectl -n starfleet-033-040-02-01 exec deploy/scout -- grep Seccomp: /proc/1/status
```

```text
Seccomp:	0
```

The profile is set, but the process still has no filter. For a privileged container, the container runtime (containerd) does not apply a seccomp profile at all. You must remove `privileged: true` as well.

## Apply Both Deployments

The files below keep the names, images, commands and replica counts. Each one sets `seccompProfile` at pod level, so every container in the pod uses it, and `scout` no longer has `privileged: true`.

Save this as `deployment-bridge.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bridge
  namespace: starfleet-033-040-02-01
spec:
  replicas: 2
  selector:
    matchLabels:
      app: bridge
  template:
    metadata:
      labels:
        app: bridge
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: bridge
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
```

Save this as `deployment-scout.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
  namespace: starfleet-033-040-02-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: scout
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
```

Apply them:

```sh
kubectl apply -f deployment-bridge.yaml
kubectl apply -f deployment-scout.yaml
```

```text
deployment.apps/bridge configured
deployment.apps/scout configured
```

Then wait for both rollouts:

```sh
kubectl -n starfleet-033-040-02-01 rollout status deployment/bridge --timeout=180s
kubectl -n starfleet-033-040-02-01 rollout status deployment/scout --timeout=180s
```

```text
Waiting for deployment "bridge" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "bridge" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "bridge" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "bridge" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "bridge" rollout to finish: 1 old replicas are pending termination...
deployment "bridge" successfully rolled out
deployment "scout" successfully rolled out
```

## Verify The Result

Wait until the old pods are gone, then list the pods and run the same loop again:

```sh
kubectl -n starfleet-033-040-02-01 get pods
for pod_name in $(kubectl -n starfleet-033-040-02-01 get pods -o name); do echo "$pod_name"; kubectl -n starfleet-033-040-02-01 exec "$pod_name" -- grep Seccomp: /proc/1/status; done
```

```text
NAME                      READY   STATUS    RESTARTS   AGE
bridge-7f694ccd89-894ln   1/1     Running   0          37s
bridge-7f694ccd89-swhxb   1/1     Running   0          36s
scout-85bc6f6cc7-wnnwc    1/1     Running   0          37s
pod/bridge-7f694ccd89-894ln
Seccomp:	2
pod/bridge-7f694ccd89-swhxb
Seccomp:	2
pod/scout-85bc6f6cc7-wnnwc
Seccomp:	2
```

Every pod now has a filter. `RuntimeDefault` is the profile that the container runtime ships. It blocks a list of rarely needed and risky system calls and allows the rest, so most applications run under it without changes.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-02-01`.

## Common pitfalls

> [!WARNING]
> - Setting `RuntimeDefault` on a privileged container. The field is accepted, but the process still reports `Seccomp: 0`.
> - Checking the field in the Deployment and not the process. Only `/proc/1/status` shows whether the filter is really there.
> - Reading `Seccomp:` from a pod that is still terminating. Wait until only the new pods are left.
