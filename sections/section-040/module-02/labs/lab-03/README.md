---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Find And Fix A Blocked System Call In A seccomp Profile

The learner diagnoses a crash-looping Deployment whose `Localhost` seccomp profile blocks the rename system calls, edits the profile on the node so that `mv` works again, keeps the `chown` family blocked, and restarts the Deployment. The lab uses a single-node pinned kind cluster. The bootstrap installs `bootstrap/profiles/cargo-guard.json` on the node, applies the Deployment and waits, with a limit, until the container has restarted at least once. Python 3 and Podman are required on the grading host, because the grader reads the profile file inside the node container.

A guard runs before both outcomes: `shuttle` keeps its container, image, command and one replica, exactly one pod is ready, the pod uses a `Localhost` profile whose file exists on the node, and `/proc/1/status` reports `Seccomp: 2`.

Outcomes (1 point each):

- `shuttle-renames-work`: the profile file keeps `SCMP_ACT_ALLOW` as the default action, and `mv` renames a file inside the pod.
- `shuttle-chown-blocked`: `chown` on a file inside the pod fails with exit code 1 and `Operation not permitted`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution (`solution/apply.sh`, which copies `solution/cargo-guard.json` to the node and restarts the Deployment) is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): every outcome failed on the start state with `Deployment rollout is incomplete`, the commands in `solution.md` produced the output quoted there, and `astrona test` passed. The run also showed that a crash-looping container picks up the changed profile at its next restart, because the kubelet reads the profile each time it creates a container.
