---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close Unused And Duplicate Root Accounts

The setup script creates three accounts on the control-plane node and sets a hashed password for each with `chpasswd`: `opsadmin` (the administrator account, `/bin/bash`), `olduser` (unused, `/bin/bash`, status `P`) and `toor` (UID 0, GID 0, home `/nonexistent`, `/bin/bash`). The home directory is `/nonexistent` so that a learner's `userdel --remove toor` cannot delete `/root`.

Three outcomes are graded. `olduser-no-login-shell` needs a refusing shell (`nologin` or `false`) and checks behaviour: `su olduser -c true` must fail. `olduser-password-locked` needs `passwd -S` status `L`, and both olduser outcomes need the account to still exist. `single-uid-zero` needs `root` to be the only `getent passwd` entry with UID 0, so deleting `toor` and changing its UID both pass. Every outcome also checks that `opsadmin` keeps a non-zero UID, `/bin/bash` and status `P`, that `kubelet` and `containerd` are active on both nodes and that `/readyz` answers `ok`. The lab seeds no Kubernetes workloads and needs no network access.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution (`usermod --shell /usr/sbin/nologin --lock olduser` and `userdel --force toor`) is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed and `verify-start.sh` failed all three outcomes on the starting state. A plain `userdel toor` failed with `user toor is currently used by process 1` (exit status 8), and `userdel --force toor` printed the same message and exited 0. The commands and output in `solution.md` come from a manual run of the same environment.
