---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has one control-plane node and the namespace `starfleet-033-020-01-03`. The node has the group `flight-ops` with the members `leaver` and `crew-member`, and the file `/srv/flight-ops/roster` that the group can read. Each of the two accounts has its own sudo rule file in `/etc/sudoers.d`.

In Kubernetes, the user `leaver` has the RoleBinding `leaver-edit` to the ClusterRole `edit` and the ClusterRoleBinding `leaver-node-reader`. The user `crew-member` has the RoleBinding `crew-member-view` to the ClusterRole `view`. The task is to remove every access of `leaver` and keep every access of `crew-member`.
