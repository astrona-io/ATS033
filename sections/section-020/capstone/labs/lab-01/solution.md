---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Harden RBAC And ServiceAccounts In Two Namespaces Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-capstone-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Inspect the starting authority

List the bindings that matter, the token Secret and the Deployment.

```sh
kubectl get clusterrolebinding deployer-admin -o wide
kubectl -n outpost get rolebinding default-edit -o wide
kubectl -n outpost get secrets --field-selector type=kubernetes.io/service-account-token
kubectl -n outpost get deployment reporter -o yaml
```

## Replace the cluster-admin binding of the deployer

Save this as `role-deployer.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: outpost
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "patch", "update"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

Save this as `rolebinding-deployer.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer
  namespace: outpost
subjects:
- kind: ServiceAccount
  name: deployer
  namespace: outpost
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deployer
```

Apply both, then delete the cluster-wide binding and the long-lived token:

```sh
kubectl apply -f role-deployer.yaml -f rolebinding-deployer.yaml
kubectl delete clusterrolebinding deployer-admin
kubectl -n outpost delete secret legacy-deployer-token
```

## Close the default ServiceAccount in outpost

Save this as `serviceaccount-default.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: outpost
automountServiceAccountToken: false
```

Apply it and delete the `edit` binding:

```sh
kubectl apply -f serviceaccount-default.yaml
kubectl -n outpost delete rolebinding default-edit
```

## Give the reporter its own identity and a bound token

The reporter reads pods in `starfleet`, so the RoleBinding lives in `starfleet` and names the ServiceAccount of `outpost` as its subject. Save this as `serviceaccount-reporter.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: reporter
  namespace: outpost
automountServiceAccountToken: false
```

Save this as `role-pod-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: starfleet
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

Save this as `rolebinding-reporter-pod-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reporter-pod-reader
  namespace: starfleet
subjects:
- kind: ServiceAccount
  name: reporter
  namespace: outpost
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

Save this as `deployment-reporter.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reporter
  namespace: outpost
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reporter
  template:
    metadata:
      labels:
        app: reporter
    spec:
      serviceAccountName: reporter
      automountServiceAccountToken: false
      containers:
      - name: reporter
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        volumeMounts:
        - name: api-token
          mountPath: /var/run/secrets/tokens
          readOnly: true
      volumes:
      - name: api-token
        projected:
          sources:
          - serviceAccountToken:
              path: api-token
              expirationSeconds: 3600
```

Apply them and wait for the rollout:

```sh
kubectl apply -f serviceaccount-reporter.yaml -f role-pod-reader.yaml -f rolebinding-reporter-pod-reader.yaml
kubectl apply -f deployment-reporter.yaml
kubectl -n outpost rollout status deployment/reporter --timeout=180s
```

## Verify the result

Ask the questions as each ServiceAccount. The answers marked `yes` must print `yes`, and the others must print `no`. A `no` ends with a nonzero status, so run the commands one at a time.

```sh
deployer=system:serviceaccount:outpost:deployer
reporter=system:serviceaccount:outpost:reporter
kubectl auth can-i patch deployments --as="$deployer" -n outpost
kubectl auth can-i delete deployments --as="$deployer" -n outpost
kubectl auth can-i patch deployments --as="$deployer" -n starfleet
kubectl auth can-i get secrets --as="$deployer" -n outpost
kubectl auth can-i create pods --as=system:serviceaccount:outpost:default -n outpost
kubectl auth can-i list pods --as="$reporter" -n starfleet
kubectl auth can-i list pods --as="$reporter" -n outpost
kubectl -n outpost exec deploy/reporter -- sh -c 'test -s /var/run/secrets/tokens/api-token && echo present || echo absent'
kubectl -n outpost exec deploy/reporter -- sh -c 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo mounted || echo absent'
```

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-020-capstone-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context before a change. Delete every old binding as well as creating the new one, because RBAC only adds permissions. Test as the ServiceAccount with `--as`, never with your own administrator session.
