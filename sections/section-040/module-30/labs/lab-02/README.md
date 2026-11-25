---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Set An AppArmor Profile For One Container

The learner finds that a pod-level `appArmorProfile` (`Localhost` `k8s-deny-tmp-write`) makes the `console` container of the pod `bridge` crash, because it cannot write under `/tmp`. The learner creates the pod again with the pod-level type `RuntimeDefault` and gives only the `logger` container the `Localhost` profile. The pod must be created again, because its security context cannot change.

The lab runs on the CKS QEMU image (Ubuntu 24.04, one-node kubeadm cluster, containerd, AppArmor enabled). A kind node shares the kernel of the Podman machine, which has no AppArmor on macOS, so the former kind version never passed `astrona test`. `scripts/ci/vm-lab.py` generates `vm/` from `bootstrap/`, `solution/`, `testing/` and `validation/`; run it again after editing those files. The bootstrap checks `/sys/module/apparmor/parameters/enabled`, copies `bootstrap/profiles/k8s-deny-tmp-write` to `/etc/apparmor.d/`, loads it in enforce mode, applies the pod and waits, with a limit, until `console` has restarted once.

The profile has `signal (receive) peer=runc,`. The solution deletes `bridge`, and without that rule the kernel denies the `kill` signal from `runc` and the pod stays in `Terminating`. The delete still takes about 30 seconds (the grace period), because `logger` ignores `SIGTERM`.

A guard runs before both outcomes: `bridge` keeps its containers, images, commands and restart policy, is ready, has the pod-level type `RuntimeDefault`, `console` uses `RuntimeDefault` and `logger` uses `Localhost` `k8s-deny-tmp-write`.

Outcomes (1 point each):

- `console-tmp-write-works`: `/proc/1/attr/current` in `console` shows a profile in enforce mode other than `k8s-deny-tmp-write`, and `touch /tmp/console-check` works.
- `logger-tmp-write-denied`: `/proc/1/attr/current` in `logger` reads `k8s-deny-tmp-write (enforce)`, and `touch /tmp/logger-check` fails with `Permission denied`.

Runtime status: passed on 2026-11-18 on Apple silicon (QEMU with HVF, image `24.04-cks` build 20261118). `astrona test` printed `PROCTOR: PASS` with 2 of 2 outcomes; verify-start rejected the unfinished lab; the run took about 106 seconds (bootstrap 57 seconds, reference-result 33 seconds). The containerd default profile is `cri-containerd.apparmor.d (enforce)`, captured live.
