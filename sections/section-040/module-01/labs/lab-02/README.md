---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Load An AppArmor Profile And Attach It To A Pod

The learner writes the AppArmor profile `k8s-deny-tmp-write`, loads it in enforce mode on the node, and creates the pod `scout` with `appArmorProfile` type `Localhost`. The lab seeds only the namespace.

The lab runs on the CKS QEMU image (Ubuntu 24.04, one-node kubeadm cluster, containerd, AppArmor enabled). A kind node shares the kernel of the Podman machine, which has no AppArmor on macOS, so the former kind version never passed `astrona test`. The VM removes the host gate, the `apt-get` install and the `securityfs` mount. `scripts/ci/vm-lab.py` generates `vm/` from `bootstrap/`, `solution/`, `testing/` and `validation/`; run it again after editing those files. The bootstrap checks `/sys/module/apparmor/parameters/enabled`, removes any old `/etc/apparmor.d/k8s-deny-tmp-write` and applies the namespace.

The profile needs `signal (receive) peer=runc,`. Without it the kernel denies the `kill` signal that `runc` sends, the audit log shows `apparmor="DENIED" operation="signal" ... signal=kill peer="runc"`, and a deleted pod stays in `Terminating`.

A guard runs before every outcome: `scout` keeps its container, image, command and restart policy, is running and ready, and has the effective profile `Localhost` `k8s-deny-tmp-write`.

Outcomes (1 point each):

- `profile-loaded-in-enforce-mode`: `/sys/kernel/security/apparmor/profiles` on the node lists `k8s-deny-tmp-write (enforce)`.
- `scout-confined`: `/proc/1/attr/current` in `scout` reads `k8s-deny-tmp-write (enforce)`.
- `scout-tmp-write-denied`: `touch /tmp/scout-check` in `scout` fails with `Permission denied`.

Runtime status: passed on 2026-11-18 on Apple silicon (QEMU with HVF, image `24.04-cks-20261118`). `astrona test` printed `PROCTOR: PASS` with 3 of 3 outcomes; verify-start rejected the unfinished lab; the run took about 64 seconds (bootstrap 46 seconds).
