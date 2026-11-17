---
exam_objectives:
- Using least-privilege identity and access management
---
# Grant Read Access Through A Group

The learner gives one node account read access to one file through a group: `chgrp` and `chmod 0640` on `/srv/flight-logs/telemetry.log`, then `usermod --append --groups flight-log-readers navigator`.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. `bootstrap/setup.sh` creates the accounts, the group and the file inside that node container only. The two outcomes are behaviour checks: a real read with `runuser -u navigator -- cat`, and a denied read with `runuser -u cadet -- cat`.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that both outcomes fail on the starting state. After `solution/apply.sh`, both outcomes passed (`2 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
