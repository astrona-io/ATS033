---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Purge An Unneeded Package From A Node

The setup script builds a small Debian package, `debug-relay` 1.4.2, on the control-plane node with `dpkg-deb --build` and installs it with `dpkg --install`. No network access is needed. The package ships `/usr/sbin/debug-relay`, `debug-relay.service` (a Python web server on `127.0.0.1:7070`) and the configuration file `/etc/debug-relay/relay.conf`, listed in `DEBIAN/conffiles`. Its `postinst` script enables and starts the service, and its `prerm` script stops and disables it.

Two outcomes are graded. `package-removed` needs a status other than installed, no program file and no listener on port 7070. `configuration-purged` needs no `dpkg` record (or a `not-installed` status) and no `relay.conf`, so `apt-get remove` alone passes only the first outcome. Every outcome also checks that `kubelet` and `containerd` are active on both nodes, that every node is `Ready` and that `/readyz` answers `ok`. The lab seeds no Kubernetes workloads; the namespace in `testing/requirements.json` is only the grader's default.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution (`apt-get purge --yes debug-relay`) is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed, `verify-start.sh` failed both outcomes on the starting state, and `apt-get purge` worked without network access. The commands and output in `solution.md` come from a manual run of the same environment.
