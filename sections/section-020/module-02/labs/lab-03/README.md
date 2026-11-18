---
exam_objectives:
- Using least-privilege identity and access management
---
# Find Hidden RBAC Grants

The learner finds and removes two hidden grants in `starfleet-033-020-02-03`. The first is a ClusterRole with the label `rbac.authorization.k8s.io/aggregate-to-view: "true"` that adds Secret access to the ClusterRole `view`. The second is the RoleBinding `crew-editors`, which gives `edit` to the group `system:serviceaccounts:starfleet-033-020-02-03`.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. `bootstrap/setup.sh` waits until the aggregation controller has copied the Secret rule into `view`, so the start check is stable. The grader also confirms that `view` keeps its `aggregationRule` and that `auditor` and `dashboard` keep their read access.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that both outcomes fail on the starting state. After `solution/apply.sh`, both outcomes passed (`2 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
