---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has the namespace `starfleet-033-020-03-03` with no workloads. The RoleBinding `default-edit` gives the ClusterRole `edit` to the `default` ServiceAccount, and `default` still mounts a token into every Pod that uses it.

The ServiceAccount `legacy-monitor` has a Secret `legacy-monitor-token` of type `kubernetes.io/service-account-token`. The token controller has filled it with a token that does not expire.
