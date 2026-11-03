---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Summary

RBAC separates what is allowed from who is allowed. A Role holds rules for one namespace, and a ClusterRole holds rules for the cluster or for non-namespaced resources. A RoleBinding gives a role to subjects in one namespace, and a ClusterRoleBinding gives a ClusterRole to subjects everywhere. The kind of binding sets the scope: a RoleBinding to a ClusterRole gives its rules in one namespace only. RBAC has no deny rule, so access exists only where some binding adds it, and deleting the binding is the way to take it back.

A rule names API groups, resources, subresources and verbs, and `resourceNames` can narrow it to named objects for verbs that carry a name. A wildcard grants everything that exists now and everything installed later, so rules should list exact values. The ClusterRole `cluster-admin` allows every action everywhere and belongs only to a few human administrators, never to a workload. Permissions that reach more power, such as creating pods, reading Secrets, executing in pods or creating RoleBindings, deserve the same care as an explicit broad grant.

Kubernetes protects RBAC itself. A user can create a role only with permissions they already hold, or with the `escalate` verb, and can create a binding only to a role they already hold, or with the `bind` verb. These two verbs switch the checks off and should be rare.

Good practice is a loop. Write the narrowest rule that completes the task, bind it in the smallest scope, delete the old binding, and prove the result as the identity with `kubectl auth can-i --as`. Then audit regularly: list bindings to `cluster-admin`, search roles for wildcards, check the `default` ServiceAccount of each namespace and remember that aggregated ClusterRoles such as `view`, `edit` and `admin` change when other ClusterRoles carry their labels.

Key facts:

- A RoleBinding never grants outside its own namespace, even when it names a ClusterRole.
- The `roleRef` of a binding cannot be changed; delete and recreate the binding.
- `resourceNames` does not restrict `list`, `watch` or `create`.
- `kubectl auth can-i --list --as=<identity> -n <namespace>` shows the complete rule set of an identity.
- Testing with your own administrator session proves nothing about a ServiceAccount.

<!-- astrona:playground:destroy -->
