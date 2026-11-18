---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Apply The RuntimeDefault seccomp Profile To Deployments

The bootstrap creates two Deployments without a seccomp filter: `bridge` (two replicas, no security context) and `scout` (one replica, `privileged: true`). The learner sets `RuntimeDefault` on both and removes `privileged`, because a privileged container gets no seccomp filter even when `RuntimeDefault` is set. The lab uses a single-node pinned kind cluster.

Each outcome has a guard for its Deployment: the name, container, image, command and replica count are unchanged, and the rollout is complete.

Outcomes (1 point each):

- `bridge-runtime-default`: both `bridge` pods run, are not privileged, have the effective profile type `RuntimeDefault` and report `Seccomp: 2`.
- `scout-runtime-default`: the `scout` pod runs, is not privileged, has the effective profile type `RuntimeDefault` and reports `Seccomp: 2`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): every outcome failed on the start state, the commands in `solution.md` produced the output quoted there, and `astrona test` passed. The run also showed that `scout` with `RuntimeDefault` and `privileged: true` still reports `Seccomp: 0`.
