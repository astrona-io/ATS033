---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Switch An AppArmor Profile From Complain To Enforce Mode

The learner finds that the profile `k8s-deny-etc-write` is loaded in complain mode on the node, reloads the same file in enforce mode with `apparmor_parser -r`, and restarts the Deployment `scout` that uses it.

The lab runs on the CKS QEMU image (Ubuntu 24.04, one-node kubeadm cluster, containerd, AppArmor enabled). A kind node shares the kernel of the Podman machine, which has no AppArmor on macOS, so the former kind version never passed `astrona test`. `scripts/ci/vm-lab.py` generates `vm/` from `bootstrap/`, `solution/`, `testing/` and `validation/`; run it again after editing those files. The bootstrap checks `/sys/module/apparmor/parameters/enabled`, copies `bootstrap/profiles/k8s-deny-etc-write` to `/etc/apparmor.d/`, loads it with `-C` and applies the Deployment.

The profile is an allow list: it allows reading and running every file and writing only under `/dev`, `/proc`, `/run`, `/tmp` and `/var`. It has no explicit `deny` rule, because a `deny` rule also blocks in complain mode (verified in the VM); only an uncovered access shows the difference between the two modes. It also has `signal (receive) peer=runc,`, because the rollout restart deletes the old pod, and without that rule the pod stays in `Terminating`.

A guard runs before both outcomes: `scout` keeps its container, image, command and one replica, the rollout is complete with exactly one pod, and the pod uses the `Localhost` profile `k8s-deny-etc-write`.

Outcomes (1 point each):

- `profile-enforced`: `/sys/kernel/security/apparmor/profiles` on the node lists `k8s-deny-etc-write (enforce)`.
- `scout-etc-write-denied`: `/proc/1/attr/current` in the pod reads `k8s-deny-etc-write (enforce)`, and `touch /etc/scout-check` fails with `Permission denied`.

Runtime status: passed on 2026-11-18 on Apple silicon (QEMU with HVF, image `24.04-cks-20261118`). `astrona test` printed `PROCTOR: PASS` with 2 of 2 outcomes; verify-start rejected the unfinished lab; the run took about 72 seconds (bootstrap 19 seconds, wait-solved 36 seconds).
