---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Restrict SSH Logins In sshd_config

The kind node image has no `sshd`, so this lab is a text-based stand-in. The setup script writes `/etc/ssh/sshd_config` (an `Include` of `sshd_config.d/*.conf` on line 2, `PermitRootLogin prohibit-password`, `PasswordAuthentication no` and a trailing `Match User backup` block), `10-legacy-root.conf` (`permitrootlogin yes` in lower case) and `50-cloud-init.conf` (`PasswordAuthentication yes`). It also creates the `opsadmin` account.

`testing/live.py` parses the files like `sshd`: `Include` globs are expanded at their position in sorted order, keywords are case-insensitive, `Keyword=value` is accepted, the first value wins, `AllowUsers` lines add up, and settings after a `Match` line are conditional until the next `Match` (or `Match all`) or the end of the file; an included file never changes the caller's state. Three outcomes are graded: `root-login-refused`, `password-login-refused` (also needs `PubkeyAuthentication yes`) and `allow-only-opsadmin` (global `AllowUsers` equal to `opsadmin`; an `AllowUsers` line appended inside the `Match` block fails with a clear message). Every outcome also checks `opsadmin` keeps `/bin/bash`, `kubelet` and `containerd` are active on both nodes and `/readyz` answers `ok`. The lab seeds no Kubernetes workloads and needs no network access.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed, `verify-start.sh` failed all three outcomes on the starting state, an `AllowUsers` line appended after the `Match` block failed `allow-only-opsadmin`, and the commands and output in `solution.md` come from a manual run of the same environment. A real `sshd -T` comparison is not possible on this image.
