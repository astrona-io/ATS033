---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Harden A Deployment To The Restricted Pod Security Level

The bootstrap creates the Deployment `scout`, which runs as root without a security context and writes `/tmp/heartbeat` every five seconds. The learner moves it to user ID 1000, makes the root filesystem read-only, mounts an `emptyDir` at `/tmp` so the heartbeat keeps working, and adds the fields that the `restricted` Pod Security level requires. Setting only `readOnlyRootFilesystem` makes the container crash, which the solution shows. The lab uses a single-node pinned kind cluster.

A guard runs before every outcome: the Deployment keeps its name, container, image, command and one replica, the rollout is complete, and exactly one `scout` pod runs and is ready.

Outcomes (1 point each):

- `scout-non-root`: `id -u` in the container is not `0`, and the effective `runAsNonRoot` is `true`.
- `scout-read-only-root`: `touch` in `/` fails with `Read-only file system`, and a write under `/tmp` works.
- `scout-restricted-admission`: `kubectl label --dry-run=server` with `pod-security.kubernetes.io/enforce=restricted` on the namespace prints no `violate` warning.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): every outcome failed on the start state, the commands in `solution.md` produced the output quoted there, and `astrona test` passed. The run also showed that the `emptyDir` mounted at `/tmp` is mode `drwxrwxrwx`, so user ID 1000 can write to it without `fsGroup`.
