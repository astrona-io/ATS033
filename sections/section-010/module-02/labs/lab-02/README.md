---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close Unused And Duplicate Root Accounts

The setup script creates three accounts in the lab VM and sets a hashed password for each with `chpasswd`: `opsadmin` (the administrator account, `/bin/bash`), `olduser` (unused, `/bin/bash`, status `P`) and `toor` (UID 0, GID 0, home `/nonexistent`, `/bin/bash`). The home directory is `/nonexistent` so that a learner's `userdel --remove toor` cannot delete `/root`.

Three outcomes are graded. `olduser-no-login-shell` needs a refusing shell (`nologin` or `false`) and checks behaviour: `su olduser -c true` must fail. `olduser-password-locked` needs `passwd -S` status `L`, and both olduser outcomes need the account to still exist. `single-uid-zero` needs `root` to be the only `getent passwd` entry with UID 0, so deleting `toor` and changing its UID both pass. Every outcome also checks that `opsadmin` keeps a non-zero UID, `/bin/bash` and status `P`, that `kubelet` and `containerd` are active and that `/readyz` answers `ok`. The lab seeds no Kubernetes workloads and needs no network access.

The task and solution use a VM from the pinned `24.04-cks` image with a one-node kubeadm cluster (Kubernetes v1.35.10). `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` (`usermod --shell /usr/sbin/nologin --lock olduser` and `userdel --force toor`) applies the reference solution and every outcome must pass.

Live run on 2026-11-18 (QEMU, `24.04-cks` image, Kubernetes v1.35.10): `astrona test` reached `PROCTOR: PASS` (3/3) and `verify-start.sh` failed all three outcomes on the starting state. A plain `userdel toor` failed with `user toor is currently used by process 1` (exit status 8), and `userdel --force toor` printed the same message and exited 0. The commands and output in `solution.md` come from a manual run in the same VM image, followed by `astrona submit` with `PROCTOR: PASS`.
