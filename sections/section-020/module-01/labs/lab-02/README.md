---
exam_objectives:
- Using least-privilege identity and access management
---
# Lock And Expire A Departed Account

The learner disables the node account `departed-user` without deleting it: lock the password, set an account expiry date in the past and change the shell to `/usr/sbin/nologin`. The account `pilot` must stay unchanged.

The lab uses its own pinned kind cluster with one control-plane node and no workloads. `bootstrap/setup.sh` creates both accounts with real password hashes through `chpasswd`, so `passwd -S` starts as `P` and the lock check fails at start. The expiry check also confirms that `su` to the account fails, which is the PAM account check and not only a field in `/etc/shadow`.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that all three outcomes fail on the starting state. After `solution/apply.sh`, all three outcomes passed (`3 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
