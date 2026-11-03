---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Replace A Wildcard Role And cluster-admin Binding Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Inspect the current authority

Start with the identity and the objects that bind it. Look at the Role, the RoleBinding and the ClusterRoleBinding, and ask the API server what the ServiceAccount may do.

```sh
account=system:serviceaccount:starfleet:ops-agent
kubectl -n starfleet get role ops-wide -o yaml
kubectl -n starfleet get rolebinding ops-wide -o wide
kubectl get clusterrolebinding ops-agent-admin -o wide
kubectl auth can-i delete secrets --as="$account" -n outpost
```

The last command answers `yes`, because the ClusterRoleBinding to `cluster-admin` applies in every namespace. Deleting only the Role would leave that path open.

## Create the narrow Role and its binding

Save this as `role-ops-agent-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ops-agent-reader
  namespace: starfleet
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

Save this as `rolebinding-ops-agent-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-agent-reader
  namespace: starfleet
subjects:
- kind: ServiceAccount
  name: ops-agent
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ops-agent-reader
```

Apply both:

```sh
kubectl apply -f role-ops-agent-reader.yaml -f rolebinding-ops-agent-reader.yaml
```

## Remove the old paths

RBAC only adds permissions, so the wide access stays until you delete the bindings. Delete the ClusterRoleBinding, the RoleBinding and the Role:

```sh
kubectl delete clusterrolebinding ops-agent-admin
kubectl -n starfleet delete rolebinding ops-wide
kubectl -n starfleet delete role ops-wide
```

## Verify the result

Ask the questions as the ServiceAccount. The first three must answer `yes`. The last five must answer `no`, and `kubectl auth can-i` ends with a nonzero status when the answer is `no`, so run the commands one at a time.

```sh
kubectl auth can-i list pods --as="$account" -n starfleet
kubectl auth can-i get pods --as="$account" -n starfleet
kubectl auth can-i get pods/log --as="$account" -n starfleet
kubectl auth can-i delete pods --as="$account" -n starfleet
kubectl auth can-i get secrets --as="$account" -n starfleet
kubectl auth can-i create deployments --as="$account" -n starfleet
kubectl auth can-i list pods --as="$account" -n outpost
kubectl auth can-i list nodes --as="$account"
```

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-020-02-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context before a change. Delete every old binding as well as creating the new one, because RBAC only adds permissions. Test as the ServiceAccount with `--as`, never with your own administrator session.
