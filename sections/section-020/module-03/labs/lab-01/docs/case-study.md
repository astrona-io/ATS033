---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has the namespace `starfleet-033-020-03-01` with two Deployments, `monitor` and `probe`, one replica each. Both run as the `default` ServiceAccount, and the kubelet mounts its token into both Pods.

The Role `pod-reader` allows `get`, `list` and `watch` on Pods. No RoleBinding uses it yet, and the ServiceAccount `monitor` does not exist yet.
