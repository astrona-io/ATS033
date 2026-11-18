---
exam_objectives:
- Using least-privilege identity and access management
---
# Scope Access With resourceNames And A RoleBinding Solution

Select the private cluster first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-01" || exit 1
```

`kubectl auth can-i <verb> <resource> --as=<user>` asks the API server whether that user may send that request. A ServiceAccount has the user name `system:serviceaccount:<namespace>:<name>`. Put the two names in variables so the commands stay short:

```sh
reviewer=system:serviceaccount:starfleet-033-020-02-01:code-reviewer
inspector=system:serviceaccount:outpost-033-020-02-01:inspector
```

## 1. Inspect the starting state

```sh
kubectl -n starfleet-033-020-02-01 get configmaps
kubectl auth can-i get configmap/probe-code --as=$reviewer -n starfleet-033-020-02-01
```

```text
NAME               DATA   AGE
bridge-settings    1      22s
kube-root-ca.crt   1      22s
probe-code         1      22s
no
```

The namespace has three ConfigMaps, and `code-reviewer` has no access yet. Next, look at the binding of `inspector`:

```sh
kubectl get clusterrolebindings -o wide --field-selector metadata.name=inspector-view
kubectl auth can-i list pods --as=$inspector -n kube-system
```

```text
NAME             ROLE               AGE   USERS   GROUPS   SERVICEACCOUNTS
inspector-view   ClusterRole/view   22s                    outpost-033-020-02-01/inspector
yes
```

A ClusterRoleBinding grants its role in every namespace, so `inspector` can even read Pods in `kube-system`.

## 2. Allow get on one ConfigMap only

The field `resourceNames` limits a rule to objects with these names. The API server can check a name only when the request names one object, so `resourceNames` works for `get`, `update`, `patch` and `delete`. It never allows `list` or `watch` on the whole collection, which is what you want here.

Save this as `role-probe-code-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: probe-code-reader
  namespace: starfleet-033-020-02-01
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["probe-code"]
  verbs: ["get"]
```

Save this as `rolebinding-code-reviewer.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: code-reviewer
  namespace: starfleet-033-020-02-01
subjects:
- kind: ServiceAccount
  name: code-reviewer
  namespace: starfleet-033-020-02-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: probe-code-reader
```

Apply them:

```sh
kubectl apply -f role-probe-code-reader.yaml
kubectl apply -f rolebinding-code-reviewer.yaml
```

```text
role.rbac.authorization.k8s.io/probe-code-reader created
rolebinding.rbac.authorization.k8s.io/code-reviewer created
```

Then check the result:

```sh
kubectl auth can-i get configmap/probe-code --as=$reviewer -n starfleet-033-020-02-01
kubectl auth can-i get configmap/bridge-settings --as=$reviewer -n starfleet-033-020-02-01
kubectl auth can-i list configmaps --as=$reviewer -n starfleet-033-020-02-01
```

```text
yes
no
no
```

`kubectl auth can-i --list` shows the whole rule set of a user. Its output for `code-reviewer` is long, because every user may call discovery URLs such as `/api` and `/healthz`. The last line is the rule from the new Role:

```sh
kubectl auth can-i --list --as=$reviewer -n starfleet-033-020-02-01
```

```text
configmaps                                      []                                     [probe-code]     [get]
```

The output above is shortened to that last line.

## 3. Bind view in one namespace only

A RoleBinding can reference a ClusterRole. The API server then grants the ClusterRole's rules only inside the RoleBinding's namespace. The subject can come from any namespace, so the binding names the namespace of `inspector`.

Save this as `rolebinding-inspector-view.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: inspector-view
  namespace: starfleet-033-020-02-01
subjects:
- kind: ServiceAccount
  name: inspector
  namespace: outpost-033-020-02-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
```

Apply it, and delete the ClusterRoleBinding:

```sh
kubectl apply -f rolebinding-inspector-view.yaml
kubectl delete clusterrolebinding inspector-view
```

```text
rolebinding.rbac.authorization.k8s.io/inspector-view created
clusterrolebinding.rbac.authorization.k8s.io "inspector-view" deleted
```

Then check the result:

```sh
kubectl auth can-i list pods --as=$inspector -n starfleet-033-020-02-01
kubectl auth can-i list pods --as=$inspector -n kube-system
kubectl auth can-i list pods --as=$inspector -n outpost-033-020-02-01
```

```text
yes
no
no
```

`inspector` reads only `starfleet-033-020-02-01`. It has no access even in its own namespace. Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-02-01`.

## Common pitfalls

> [!WARNING]
> - **Expecting `resourceNames` to allow `list`.** A list request names no object, so a rule with `resourceNames` never matches it.
> - **Keeping the ClusterRoleBinding.** RBAC only adds permissions. A new RoleBinding does not remove the cluster-wide access; you must delete the ClusterRoleBinding.
> - **Wrong subject namespace.** The subject of the RoleBinding is `inspector` in `outpost-033-020-02-01`, not in the namespace of the binding.
> - **Testing without the full name.** `--as=inspector` tests a user called `inspector`, not the ServiceAccount. Use `system:serviceaccount:<namespace>:<name>`.
