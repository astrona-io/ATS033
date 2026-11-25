---
exam_objectives:
- Using least-privilege identity and access management
---
# Replace Wildcard And Cluster-Admin Access Solution

Select the private cluster and put the ServiceAccount's user name in a variable. A ServiceAccount has the user name `system:serviceaccount:<namespace>:<name>`, and `kubectl auth can-i --as` uses that name.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-02" || exit 1
agent=system:serviceaccount:starfleet-033-020-02-02:ops-agent
```

## 1. Find every binding of ops-agent

RBAC (role-based access control) only adds permissions: the API server allows a request if any binding allows it. So you must find every binding, in the namespace and cluster-wide. The `-o wide` output adds the SERVICEACCOUNTS column.

```sh
kubectl -n starfleet-033-020-02-02 get rolebindings -o wide
kubectl get clusterrolebindings -o wide --field-selector metadata.name=ops-agent-admin
```

```text
NAME       ROLE            AGE   USERS   GROUPS   SERVICEACCOUNTS
ops-wide   Role/ops-wide   27s                    starfleet-033-020-02-02/ops-agent
NAME              ROLE                        AGE   USERS   GROUPS   SERVICEACCOUNTS
ops-agent-admin   ClusterRole/cluster-admin   27s                    starfleet-033-020-02-02/ops-agent
```

On a real cluster you would run `kubectl get clusterrolebindings -o wide` without the field selector and search the SERVICEACCOUNTS column. Now confirm the problem:

```sh
kubectl auth can-i list nodes --as=$agent
kubectl auth can-i delete pods --as=$agent -n starfleet-033-020-02-02
```

```text
Warning: resource 'nodes' is not namespace scoped

yes
yes
```

## 2. Remove the cluster-wide access

```sh
kubectl delete clusterrolebinding ops-agent-admin
kubectl auth can-i list nodes --as=$agent
kubectl auth can-i list pods --as=$agent -n outpost-033-020-02-02
```

```text
clusterrolebinding.rbac.authorization.k8s.io "ops-agent-admin" deleted
Warning: resource 'nodes' is not namespace scoped

no
no
```

The ServiceAccount lost every permission outside its namespace.

## 3. Remove the wildcard Role

The Role `ops-wide` has `*` in `apiGroups`, `resources` and `verbs`. Delete the binding and the Role, so that no one can bind it again by mistake.

```sh
kubectl -n starfleet-033-020-02-02 delete rolebinding ops-wide
kubectl -n starfleet-033-020-02-02 delete role ops-wide
kubectl auth can-i list pods --as=$agent -n starfleet-033-020-02-02
```

```text
rolebinding.rbac.authorization.k8s.io "ops-wide" deleted from starfleet-033-020-02-02 namespace
role.rbac.authorization.k8s.io "ops-wide" deleted from starfleet-033-020-02-02 namespace
no
```

`ops-agent` now has no access at all.

## 4. Grant only the reads it needs

Pod logs are a subresource. A rule on `pods` does not cover `pods/log`, so it needs its own rule.

Save this as `role-ops-agent-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ops-agent-reader
  namespace: starfleet-033-020-02-02
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
  namespace: starfleet-033-020-02-02
subjects:
- kind: ServiceAccount
  name: ops-agent
  namespace: starfleet-033-020-02-02
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ops-agent-reader
```

Apply them:

```sh
kubectl apply -f role-ops-agent-reader.yaml
kubectl apply -f rolebinding-ops-agent-reader.yaml
```

```text
role.rbac.authorization.k8s.io/ops-agent-reader created
rolebinding.rbac.authorization.k8s.io/ops-agent-reader created
```

Then check the result. `kubectl describe role` prints the rules as a table:

```sh
kubectl -n starfleet-033-020-02-02 describe role ops-agent-reader
```

```text
Name:         ops-agent-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [get list]
  pods/log   []                 []              [get]
```

Ask the API server about the allowed and the denied requests:

```sh
kubectl auth can-i list pods --as=$agent -n starfleet-033-020-02-02
kubectl auth can-i get pods --as=$agent -n starfleet-033-020-02-02
kubectl auth can-i get pods/log --as=$agent -n starfleet-033-020-02-02
kubectl auth can-i delete pods --as=$agent -n starfleet-033-020-02-02
kubectl auth can-i create pods/exec --as=$agent -n starfleet-033-020-02-02
kubectl auth can-i get secrets --as=$agent -n starfleet-033-020-02-02
kubectl auth can-i create deployments --as=$agent -n starfleet-033-020-02-02
```

```text
yes
yes
yes
no
no
no
no
```

The three reads are allowed and everything else is denied. Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-02-02`.

## Common pitfalls

> [!WARNING]
> - **Removing only one route.** RBAC has no deny rules. If any binding still grants a permission, the request is allowed.
> - **Forgetting `pods/log`.** `get` on `pods` does not allow `kubectl logs`. Name the subresource.
> - **Leaving the wildcard Role.** A Role without a binding grants nothing, but someone can bind it again later. Delete it.
> - **Reading `can-i` output loosely.** For nodes, `kubectl` prints a warning before the answer. Read the last line, or check the exit code: `0` means yes and `1` means no.
