---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has the namespace `starfleet-033-020-02-03` with the Secret `bridge-credentials`, the ServiceAccount `dashboard` and three RoleBindings. `auditor-view` and `dashboard-view` bind the ClusterRole `view` to the user `auditor` and to `dashboard`.

Two more objects give extra access. A ClusterRole with the label `rbac.authorization.k8s.io/aggregate-to-view: "true"` adds Secret access to `view`. The RoleBinding `crew-editors` gives `edit` to the group of all ServiceAccounts in the namespace. The task is to find and remove both.
