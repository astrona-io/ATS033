# Roles, ClusterRoles And Bindings

The API server checks every request against the RBAC rules before it runs the request. RBAC stands for role-based access control: a set of Kubernetes objects that say who may do what through the API. If the rules are wrong, two things can happen. A workload fails because it lacks a permission, or, worse, it succeeds because it holds far more than it needs.

To write correct rules, you must know exactly what each of the four RBAC kinds contains and where each one applies. On this page, you build a Role, see what a ClusterRole adds, and see how the kind of binding decides the scope.

## The four kinds and what they hold

RBAC keeps two questions apart: what is allowed, and who is allowed. Two kinds hold the rules, and two kinds hand those rules to someone:

- A **Role** holds rules and lives in one namespace.
- A **ClusterRole** holds rules and is not namespaced. It can describe resources that exist outside any namespace (nodes, namespaces, PersistentVolumes), URLs that are not resources (`/healthz`), or the same namespaced resources as a Role.
- A **RoleBinding** lives in one namespace and gives a Role or a ClusterRole to subjects.
- A **ClusterRoleBinding** gives a ClusterRole to subjects in every namespace and for cluster-scoped resources.

A subject is the identity that receives the rules: a user, a group or a ServiceAccount. A ServiceAccount is the identity that a pod uses when it talks to the API server.

Each rule has four parts. Together they describe one kind of request:

- `apiGroups` names the API group. The empty string means the core group, where `pods`, `secrets` and `configmaps` live.
- `resources` names the resource. A slash adds a subresource, such as `pods/log` or `pods/exec`.
- `verbs` names the actions: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` and a few others.
- The optional `resourceNames` restricts the rule to named objects.

RBAC has no deny rule. The API server allows a request when at least one rule from any binding of the subject matches it. If no rule matches, the API server rejects the request.

![Diagram: a RoleBinding in starfleet that points to a Role or a ClusterRole grants the rules only in starfleet, while a ClusterRoleBinding grants a ClusterRole in all namespaces](images/binding-sets-scope.svg)

The drawing shows that the binding, not the role, decides the scope: a RoleBinding limits even a ClusterRole to its own namespace.

## Build a narrow Role

The playground has a `shuttle` pod and a `probe` Deployment in `starfleet`. A reporting tool needs to read the configuration in one ConfigMap, not in all of them. First, point `kubectl` at the playground cluster:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-02" || exit 1
```

The reporting tool needs its own identity, so start with a ServiceAccount. Save this as `serviceaccount-report-reader.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: report-reader
  namespace: starfleet
```

Next comes the Role. It allows one verb, `get`, on one ConfigMap, `probe-code`, in the core API group. Save this as `role-probe-code-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: probe-code-reader
  namespace: starfleet
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["probe-code"]
  verbs: ["get"]
```

The Role does nothing until a binding gives it to a subject. The RoleBinding below connects the Role to the ServiceAccount. Save this as `rolebinding-report-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-reader-probe-code
  namespace: starfleet
subjects:
- kind: ServiceAccount
  name: report-reader
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: probe-code-reader
```

Apply all three:

```sh
kubectl apply -f serviceaccount-report-reader.yaml -f role-probe-code-reader.yaml -f rolebinding-report-reader.yaml
```

Then check the result. Ask the API server, acting as the ServiceAccount, three questions: may it read the named ConfigMap, may it list ConfigMaps, and may it read the same ConfigMap in another namespace?

```sh
account=system:serviceaccount:starfleet:report-reader
kubectl auth can-i get configmap/probe-code --as="$account" -n starfleet
kubectl auth can-i list configmaps --as="$account" -n starfleet
kubectl auth can-i get configmap/probe-code --as="$account" -n outpost
```

The answers are `yes`, `no` and `no`. The `resourceNames` list allows only the `get` of that one object. A `list` request has no object name, so a rule with `resourceNames` never matches it. A `no` answer ends the command with a nonzero exit status, which is normal.

![Diagram: the report-reader ServiceAccount may get configmap/probe-code in starfleet, but may not list configmaps and may not get probe-code in outpost](images/resource-names-checks.svg)

The drawing shows the three questions. Only the first one matches the rule: the right verb, the right object name and the namespace of the RoleBinding.

## Limit a ClusterRole with a RoleBinding

Writing every rule by hand is slow, so Kubernetes ships ready-made ClusterRoles. One of them is `view`, which grants read access to most namespaced resources. A ClusterRoleBinding to `view` would give that read access in every namespace. A RoleBinding that points to the same ClusterRole gives it in one namespace only. You reuse the rules and still limit the scope.

Save this as `rolebinding-report-reader-view.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-reader-view
  namespace: starfleet
subjects:
- kind: ServiceAccount
  name: report-reader
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
```

Apply it:

```sh
kubectl apply -f rolebinding-report-reader-view.yaml
```

Then check the result in both namespaces:

```sh
kubectl auth can-i list pods --as="$account" -n starfleet
kubectl auth can-i list pods --as="$account" -n outpost
```

The first answer is `yes` and the second is `no`. The `view` ClusterRole does not include Secrets, so the ServiceAccount still cannot read them.

One more detail matters when you fix a binding. The `roleRef` field, which names the role of a binding, cannot change after creation. So a wrong `roleRef` means deleting the binding and creating it again.

## Choosing the right kind

With these examples in mind, the choice of kind follows from the scope that the permission needs:

- Use a Role and a RoleBinding when the permission is about one namespace. This fits most workloads.
- Use a ClusterRole with a RoleBinding when several namespaces need the same rules, but each one grants them separately.
- Use a ClusterRole with a ClusterRoleBinding only for cluster-scoped resources such as nodes, or for a tool that truly works across all namespaces.

When you are not sure, start with the smaller scope.

You now know what each kind holds, how `resourceNames` narrows a rule and how the binding sets the scope. The open question is how permissions grow far beyond this in real clusters, and what Kubernetes does to stop users from granting what they do not hold.

## Common pitfalls

> [!WARNING]
> - **Using a ClusterRoleBinding where a RoleBinding is enough.** The permission then applies in every namespace.
> - **Expecting `resourceNames` to restrict `list`, `watch` or `create`.** These verbs have no object name in the request, so the rule does not match.
> - **Forgetting the empty string in `apiGroups`.** Core resources such as pods need `""`, not `"v1"`.
> - **Testing as yourself.** An administrator can do everything. Test with `--as=system:serviceaccount:<namespace>:<name>`.
