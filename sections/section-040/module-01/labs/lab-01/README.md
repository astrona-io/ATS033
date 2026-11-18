---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Install And Use A Localhost seccomp Profile

The learner installs a seccomp profile that the bootstrap left at `/opt/course/seccomp/scout-guard.json` on the node into `/var/lib/kubelet/seccomp/profiles/`, then runs the pod `scout` under it. The lab uses a single-node pinned kind cluster. Python 3 and Podman are required on the grading host, because the grader compares the installed file with the original inside the node container.

Outcomes (1 point each):

- `scout-localhost-profile`: the installed file matches the original, the effective profile of the container is `Localhost` `profiles/scout-guard.json`, `/proc/1/status` reports `Seccomp: 2` and a write under `/tmp` works.
- `scout-mkdir-blocked`: `mkdir` fails with `Operation not permitted` while the pod uses that profile.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): every outcome failed on the start state with `Missing pod scout`, the commands in `solution.md` produced the output quoted there, and `astrona test` passed.
