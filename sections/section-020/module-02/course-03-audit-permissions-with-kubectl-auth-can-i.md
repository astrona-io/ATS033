---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Audit Permissions With kubectl auth can-i

A cluster that has run for a year holds RoleBindings that nobody remembers. You cannot judge them by their names. You judge them by what they allow, and the fastest way to learn that is to ask the API server. This part uses `kubectl auth can-i` to test single actions and full permission lists, explains aggregated ClusterRoles, which change without anyone editing them, and lists the bindings that carry the most risk.

## Ask the API server

`kubectl auth can-i <verb> <resource>` sends a SelfSubjectAccessReview to the API server and prints `yes` or `no`. The answer comes from the same authorizer that decides real requests, so it is more reliable than reading YAML. The option `--as=<user>` sends the question as another identity, which needs permission to impersonate. Add `-n <namespace>` for a namespaced question. The option `--list` prints every rule that applies to the identity in that namespace.

Select the playground first:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-02" || exit 1
```

The playground has a ServiceAccount `ops-agent` that was bound too widely. Test it with single questions and then with the complete list:

```sh
account=system:serviceaccount:starfleet:ops-agent
kubectl auth can-i delete secrets --as="$account" -n outpost
kubectl auth can-i '*' '*' --as="$account"
kubectl auth can-i --list --as="$account" -n starfleet
```

The first two answers are `yes`. The third command shows a rule for every resource and every verb. A list that contains `*.*` with `[*]` means the identity can do everything. Compare this with a narrow identity: its list shows only the resources you named, plus the few rules every authenticated caller receives, such as `selfsubjectaccessreviews`.

A user can also ask the same question for another subject type. `--as-group` adds a group, and a user name such as `jane` can be tested with `--as=jane`. A request about a non-resource URL uses the path instead of a resource, for example `kubectl auth can-i get /healthz`.

## Aggregated ClusterRoles

Some ClusterRoles, such as `admin`, `edit` and `view`, do not hold their own rules. They hold an `aggregationRule`, which names label selectors, and a controller in `kube-controller-manager` copies the rules of every ClusterRole that matches the labels into the aggregated role. This is how a new custom resource definition (CRD) gets included in `view` when its author adds the label `rbac.authorization.k8s.io/aggregate-to-view: "true"` to a ClusterRole.

The effect is that a binding to `edit` can grow without any change to the binding or to `edit` itself. Anyone who can create a ClusterRole with an aggregation label changes the power of every subject bound to the aggregated role. You cannot edit the rules of an aggregated role by hand either, because the controller overwrites them. Inspect the selector:

```sh
kubectl get clusterrole view -o jsonpath='{.aggregationRule}{"\n"}'
kubectl get clusterrole -l rbac.authorization.k8s.io/aggregate-to-view=true
```

The first command prints the label selector. The second lists the ClusterRoles that feed `view`. When you build a custom role that should include these rules, bind to the aggregated role or give your own role the same labels deliberately.

## Find over-broad bindings

Start from the objects that grant the most. List every ClusterRoleBinding with the role and the subjects, and look for `cluster-admin` and for subjects that are ServiceAccounts or broad groups:

```sh
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name
```

On a `kind` cluster, `cluster-admin` is bound to the group `system:masters` and to the group `kubeadm:cluster-admins`. Any binding to `cluster-admin` for a ServiceAccount, such as `ops-agent-admin` here, needs a justification. Next list the RoleBindings in all namespaces, and search the rules of Roles and ClusterRoles for the wildcard character:

```sh
kubectl get rolebindings --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name
kubectl get roles,clusterroles --all-namespaces -o yaml | grep -n -B6 '\- .\*.'
```

The second command prints each wildcard entry with the six lines before it, which shows the rule and often the role name. The built-in ClusterRoles `cluster-admin` and a few `system:` roles contain wildcards by design, so look at the custom ones. After you find a suspect, open the role with `kubectl get role <name> -o yaml`, decide what the workload needs, and replace the role as in the previous part.

Finally, check the identities that every pod can use. Ask what the `default` ServiceAccount of a namespace may do, because pods that name no ServiceAccount inherit it:

```sh
kubectl auth can-i --list --as=system:serviceaccount:starfleet:default -n starfleet
```

The list must show only the rules every authenticated caller receives. Any extra rule means someone bound a role to `default`.

You now can test an identity from the outside, explain why an aggregated role changes over time and walk through a cluster looking for the bindings that matter. Together with the earlier parts, this gives you the full loop: write narrowly, bind narrowly, prove it and keep auditing.

## Common pitfalls

> [!WARNING]
> - **Trusting a role name.** A role called `reader` can still hold a wildcard. Read the rules or ask `can-i --list`.
> - **Forgetting `-n`.** Without a namespace, `kubectl` asks in the namespace of your current context.
> - **Missing the aggregated roles.** A binding to `view`, `edit` or `admin` follows the labels on other ClusterRoles.
> - **Reading only RoleBindings.** A ClusterRoleBinding grants the same power in every namespace.
