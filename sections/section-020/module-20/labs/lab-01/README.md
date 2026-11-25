---
exam_objectives:
- Using least-privilege identity and access management
---
# Scope Access With resourceNames And A RoleBinding

The learner gives the ServiceAccount `code-reviewer` read access to exactly one ConfigMap, `probe-code`, through a Role with `resourceNames`. The learner also replaces the ClusterRoleBinding `inspector-view` with a RoleBinding in `starfleet-033-020-02-01`, so that the ServiceAccount `inspector` from `outpost-033-020-02-01` keeps the ClusterRole `view` in that one namespace only.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. The grader uses exact `kubectl auth can-i` answers (`yes` with exit code 0, `no` with exit code 1) and checks the binding objects, so a wider grant such as `list configmaps` or a leftover ClusterRoleBinding fails.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that both outcomes fail on the starting state. After `solution/apply.sh`, both outcomes passed (`2 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
