# Summary

RBAC (role-based access control) keeps apart what is allowed and who is allowed. A Role holds rules for one namespace. A ClusterRole holds rules for the cluster or for non-namespaced resources. A RoleBinding gives a role to subjects in one namespace, and a ClusterRoleBinding gives a ClusterRole to subjects everywhere.

The kind of binding sets the scope. A RoleBinding to a ClusterRole gives its rules in one namespace only. RBAC has no deny rule, so access exists only where some binding adds it. To take access back, you delete the binding.

A rule names API groups, resources, subresources and verbs. The field `resourceNames` can narrow a rule to named objects, but only for verbs that carry a name. A wildcard grants everything that exists now and everything installed later, so rules should list exact values.

The ClusterRole `cluster-admin` allows every action everywhere. It belongs only to a few human administrators, never to a workload. Some permissions lead to more power: creating pods, reading Secrets, running commands in pods with `pods/exec`, or creating RoleBindings. They deserve the same care as an explicit broad grant.

Kubernetes protects RBAC itself. A user can create a role only with permissions they already hold, or with the `escalate` verb. A user can create a binding only to a role they already hold, or with the `bind` verb. These two verbs switch the checks off and should be rare.

Good practice is a loop. Write the narrowest rule that completes the task, bind it in the smallest scope, delete the old binding, and prove the result as the identity with `kubectl auth can-i --as`. Then audit on a regular schedule. List the bindings to `cluster-admin`, search roles for wildcards and check the `default` ServiceAccount of each namespace. Remember that aggregated ClusterRoles such as `view`, `edit` and `admin` change when other ClusterRoles carry their labels.

Key facts to remember:

- A RoleBinding never grants outside its own namespace, even when it names a ClusterRole.
- The `roleRef` of a binding cannot be changed; delete and recreate the binding.
- `resourceNames` does not restrict `list`, `watch` or `create`.
- `kubectl auth can-i --list --as=<identity> -n <namespace>` shows the complete rule set of an identity.
- Testing with your own administrator session proves nothing about a ServiceAccount.

<!-- astrona:playground:destroy -->
