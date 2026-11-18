---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has the namespaces `starfleet-033-020-02-02` and `outpost-033-020-02-02` and no workloads. The ServiceAccount `ops-agent` in `starfleet-033-020-02-02` has two bindings: the RoleBinding `ops-wide` to the wildcard Role `ops-wide`, and the ClusterRoleBinding `ops-agent-admin` to `cluster-admin`.

The task is to remove both routes and give `ops-agent` only read access to Pods and Pod logs in its own namespace.
