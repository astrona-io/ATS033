---
exam_objectives:
- Using least-privilege identity and access management
---
# Replace Wildcard And Cluster-Admin Access

The learner removes the ClusterRoleBinding `ops-agent-admin` to `cluster-admin` and the wildcard Role and RoleBinding `ops-wide`. The learner then gives the ServiceAccount `ops-agent` a Role `ops-agent-reader` with exactly `get` and `list` on Pods and `get` on `pods/log` in `starfleet-033-020-02-02`.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. The grader compares the flattened rules of every role bound to `ops-agent` with the expected set, so an extra verb, resource or `resourceNames` entry fails. It also uses exact `kubectl auth can-i` answers for allowed and denied actions.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that all three outcomes fail on the starting state. After `solution/apply.sh`, all three outcomes passed (`3 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
