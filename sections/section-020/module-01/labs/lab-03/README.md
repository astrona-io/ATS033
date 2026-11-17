---
exam_objectives:
- Using least-privilege identity and access management
---
# Revoke A Leaver's Access Everywhere

The learner removes every access of the person `leaver`: the node group `flight-ops`, a sudo rule file in `/etc/sudoers.d`, a RoleBinding and a ClusterRoleBinding for the user name `leaver`, and the password. The account `crew-member` must keep the same kinds of access.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. The kind node image has no `sudo` program and no SSH server, so the sudo outcome grades the rule files and runs `visudo -c` only if the node has it. The RBAC outcome uses strict `kubectl auth can-i --as=leaver` answers.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that all four outcomes fail on the starting state. After `solution/apply.sh`, all four outcomes passed (`4 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
