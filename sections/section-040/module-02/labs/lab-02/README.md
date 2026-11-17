---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Block File Deletion With A Localhost seccomp Profile

The learner writes a seccomp profile, places it in the kubelet seccomp directory of the node and runs the pod `no-delete` under it. The lab uses a single-node pinned kind cluster and seeds only the empty namespace. Python 3 and Podman are required on the grading host, because the grader reads the profile file inside the node container.

A guard runs before both outcomes: `no-delete` keeps its container, image, command and restart policy, runs, and has the effective profile `Localhost` `profiles/block-delete.json`.

Outcomes (1 point each):

- `no-delete-pod`: the profile file on the node has `defaultAction` `SCMP_ACT_ALLOW` and an `SCMP_ACT_ERRNO` rule for `unlink`, `unlinkat` and `rmdir`, `/proc/1/status` reports `Seccomp: 2`, and a write under `/tmp` works.
- `delete-blocked`: one command creates a file and removes it with `rm`, and the `rm` fails with `Operation not permitted`. The check creates its own file, so it does not depend on the order of the checks.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): every outcome failed on the start state with `Missing pod no-delete`, the commands in `solution.md` produced the output quoted there, and `astrona test` passed.
