---
exam_objectives:
- Using least-privilege identity and access management
---
# Give A Workload Its Own ServiceAccount Solution

Select the private cluster. A ServiceAccount has the user name `system:serviceaccount:<namespace>:<name>`, so put the `monitor` user name in a variable for the checks.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-01" || exit 1
monitor=system:serviceaccount:starfleet-033-020-03-01:monitor
```

## 1. Look at the starting state

```sh
kubectl -n starfleet-033-020-03-01 get pods -o custom-columns=NAME:.metadata.name,ACCOUNT:.spec.serviceAccountName
```

```text
NAME                       ACCOUNT
monitor-79d77984bf-j7nr6   default
probe-549f97cdb9-xj97l     default
```

Both Pods run as `default`. The kubelet mounts a token for that ServiceAccount into each container:

```sh
kubectl -n starfleet-033-020-03-01 exec deploy/probe -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
ca.crt
namespace
token
```

The Role `pod-reader` already holds the permission that `monitor` needs:

```sh
kubectl -n starfleet-033-020-03-01 describe role pod-reader
```

```text
Name:         pod-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [get list watch]
```

## 2. Create the ServiceAccount and bind it

Save this as `serviceaccount-monitor.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitor
  namespace: starfleet-033-020-03-01
```

Apply it:

```sh
kubectl apply -f serviceaccount-monitor.yaml
```

```text
serviceaccount/monitor created
```

Save this as `rolebinding-monitor-pod-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitor-pod-reader
  namespace: starfleet-033-020-03-01
subjects:
- kind: ServiceAccount
  name: monitor
  namespace: starfleet-033-020-03-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

Apply it:

```sh
kubectl apply -f rolebinding-monitor-pod-reader.yaml
```

```text
rolebinding.rbac.authorization.k8s.io/monitor-pod-reader created
```

Then check the result:

```sh
kubectl auth can-i list pods --as=$monitor -n starfleet-033-020-03-01
kubectl auth can-i get secrets --as=$monitor -n starfleet-033-020-03-01
```

```text
yes
no
```

## 3. Run monitor as the new ServiceAccount

Set `serviceAccountName` in the Pod template. A Pod cannot change its ServiceAccount, so the Deployment controller creates a new Pod. Save this as `deployment-monitor.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitor
  namespace: starfleet-033-020-03-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monitor
  template:
    metadata:
      labels:
        app: monitor
    spec:
      serviceAccountName: monitor
      containers:
      - name: monitor
        image: docker.io/library/busybox:1.37.0
        command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f deployment-monitor.yaml
kubectl -n starfleet-033-020-03-01 rollout status deployment/monitor --timeout=180s
```

```text
deployment.apps/monitor configured
Waiting for deployment "monitor" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "monitor" rollout to finish: 1 old replicas are pending termination...
deployment "monitor" successfully rolled out
```

Then check the result:

```sh
kubectl -n starfleet-033-020-03-01 exec deploy/monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
ca.crt
namespace
token
```

`monitor` keeps a token, and that token now belongs to the ServiceAccount `monitor`.

## 4. Remove the token from probe

Set `automountServiceAccountToken: false` in the Pod template. The kubelet then mounts no token into the Pod. Save this as `deployment-probe.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: starfleet-033-020-03-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      automountServiceAccountToken: false
      containers:
      - name: probe
        image: docker.io/library/busybox:1.37.0
        command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f deployment-probe.yaml
kubectl -n starfleet-033-020-03-01 rollout status deployment/probe --timeout=180s
```

```text
deployment.apps/probe configured
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
deployment "probe" successfully rolled out
```

Then check the result:

```sh
kubectl -n starfleet-033-020-03-01 exec deploy/probe -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```

The old Pods need about 30 seconds to stop, because `sleep` ignores the stop signal. After that, only the new Pods remain:

```sh
kubectl -n starfleet-033-020-03-01 get pods -o custom-columns=NAME:.metadata.name,ACCOUNT:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken
```

```text
NAME                       ACCOUNT   AUTOMOUNT
monitor-69464c67dc-lr95f   monitor   <none>
probe-65d8f98fb9-7jgvw     default   false
```

Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-03-01`.

## Common pitfalls

> [!WARNING]
> - **Turning off the token for monitor too.** `monitor` calls the API server, so it needs its token. Only `probe` gets `automountServiceAccountToken: false`.
> - **Binding the Role to `default`.** Then every Pod without its own ServiceAccount gets the permission. Bind the Role to `monitor` only.
> - **Editing the running Pod.** `serviceAccountName` cannot change on an existing Pod. Change the Deployment and let it create a new Pod.
> - **Checking an old Pod.** `kubectl exec deploy/<name>` can pick a Pod that is still stopping. If the output looks old, wait for the rollout and run it again.
