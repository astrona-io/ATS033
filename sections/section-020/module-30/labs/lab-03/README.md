---
exam_objectives:
- Using least-privilege identity and access management
---
# Close The Default ServiceAccount

The learner sets `automountServiceAccountToken: false` on the `default` ServiceAccount of `starfleet-033-020-03-03`, deletes the RoleBinding `default-edit` and deletes the long-lived token Secret `legacy-monitor-token`. The ServiceAccount `legacy-monitor` must stay.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. `bootstrap/setup.sh` waits until the token controller has filled the Secret. The grader searches by Secret type, so a token Secret with another name also fails the check.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that both outcomes fail on the starting state. After `solution/apply.sh`, both outcomes passed (`2 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
