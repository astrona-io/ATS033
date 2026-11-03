---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The `monitor` Deployment in `starfleet` runs with the `default` ServiceAccount, which receives a mounted token and has a RoleBinding `default-pod-lister`. A long-lived token Secret `legacy-monitor-token` also exists.

The `monitor` in `starfleet` carries API tokens it never uses.
