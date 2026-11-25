---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has the namespaces `starfleet-033-020-02-01` and `outpost-033-020-02-01` and no workloads. `starfleet-033-020-02-01` holds the ConfigMaps `probe-code` and `bridge-settings` and the ServiceAccount `code-reviewer`, which has no access yet.

The ServiceAccount `inspector` in `outpost-033-020-02-01` has the ClusterRole `view` in every namespace through the ClusterRoleBinding `inspector-view`. The task is to give `code-reviewer` one ConfigMap only and to limit `inspector` to one namespace.
