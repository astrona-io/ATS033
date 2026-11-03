---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The `outpost` namespace holds a `deployer` ServiceAccount bound to `cluster-admin`, a `default` ServiceAccount bound to `edit`, a `reporter` Deployment that runs with the `default` ServiceAccount, and a long-lived token Secret.

Two teams in `starfleet` and `outpost` share one cluster, and several ServiceAccounts hold more authority and more tokens than their workloads need.
