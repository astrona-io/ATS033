---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The `ops-agent` ServiceAccount in `starfleet` is bound to a Role `ops-wide` that allows every verb on every resource, and to `cluster-admin` through the ClusterRoleBinding `ops-agent-admin`. The agent only needs to read pods and their logs in `starfleet`.

The `ops-agent` in `starfleet` has far more authority than its task needs.
