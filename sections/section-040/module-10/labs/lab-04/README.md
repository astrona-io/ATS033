---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Fix A Pod That References A Missing seccomp Profile

The bootstrap installs the profile `profiles/shuttle-guard.json` on the node and creates the Deployment `shuttle`, whose pod template points at the misspelled `profiles/shutle-guard.json`. The pod stays in `CreateContainerError`, and its events name the missing file. The learner reads the events, compares the path with the files on the node and corrects the Deployment. The lab uses a single-node pinned kind cluster. Python 3 and Podman are required on the grading host, because the grader compares the profile in use with the approved file inside the node container.

A guard runs before both outcomes: the Deployment keeps its name, container, image, command and one replica, the rollout is complete, exactly one `shuttle` pod runs, and its effective profile is `Localhost` with the same content as `shuttle-guard.json`. Copying the profile to the misspelled name also passes, because the kubelet retries and the pod then starts under the approved content.

Outcomes (1 point each):

- `shuttle-running-filtered`: `/proc/1/status` in the running pod reports `Seccomp: 2`.
- `shuttle-chmod-blocked`: `chmod` on a file under `/tmp` fails with `Operation not permitted`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): every outcome failed on the start state with `Deployment rollout is incomplete`, the commands in `solution.md` produced the output quoted there, and `astrona test` passed.
