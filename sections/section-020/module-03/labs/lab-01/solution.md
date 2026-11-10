---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Give A Workload Its Own ServiceAccount And Remove Its Tokens Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Inspect the token paths

Look at what the pod receives today and which bindings the `default` ServiceAccount holds.

```sh
kubectl -n starfleet-033-020-03-01 get deployment monitor -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
kubectl -n starfleet-033-020-03-01 exec deploy/monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n starfleet-033-020-03-01 get rolebinding default-pod-lister -o wide
kubectl -n starfleet-033-020-03-01 get secrets --field-selector type=kubernetes.io/service-account-token
```

The first command prints nothing, because the pod template names no ServiceAccount and the pod falls back to `default`. The directory holds `ca.crt`, `namespace` and `token`. The Secret `legacy-monitor-token` never expires.

## Create the dedicated ServiceAccount and move the Deployment

Save this as `serviceaccount-monitor.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitor
  namespace: starfleet-033-020-03-01
automountServiceAccountToken: false
```

Save this as `deployment-monitor.yaml`:

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
      automountServiceAccountToken: false
      containers:
      - name: monitor
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
```

Apply both and wait for the new pod:

```sh
kubectl apply -f serviceaccount-monitor.yaml
kubectl apply -f deployment-monitor.yaml
kubectl -n starfleet-033-020-03-01 rollout status deployment/monitor --timeout=180s
```

## Close the default ServiceAccount and the old token

Save this as `serviceaccount-default.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: starfleet-033-020-03-01
automountServiceAccountToken: false
```

Apply it, then delete the binding and the Secret:

```sh
kubectl apply -f serviceaccount-default.yaml
kubectl -n starfleet-033-020-03-01 delete rolebinding default-pod-lister
kubectl -n starfleet-033-020-03-01 delete secret legacy-monitor-token
```

## Verify the result

The new pod must have no token directory, and the two ServiceAccounts must be unable to read pods or Secrets.

```sh
kubectl -n starfleet-033-020-03-01 exec deploy/monitor -- sh -c 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo mounted || echo absent'
kubectl auth can-i list pods --as=system:serviceaccount:starfleet-033-020-03-01:default -n starfleet-033-020-03-01
kubectl auth can-i get secrets --as=system:serviceaccount:starfleet-033-020-03-01:default -n starfleet-033-020-03-01
kubectl auth can-i list pods --as=system:serviceaccount:starfleet-033-020-03-01:monitor -n starfleet-033-020-03-01
```

The first command prints `absent`. The three `can-i` commands print `no`.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-020-03-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context before a change. Delete every old binding as well as creating the new one, because RBAC only adds permissions. Test as the ServiceAccount with `--as`, never with your own administrator session.
