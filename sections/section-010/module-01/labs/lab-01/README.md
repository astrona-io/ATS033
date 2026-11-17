---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close An Unneeded Listener On A Node

The setup script installs `remote-diag.service` in `/usr/lib/systemd/system` on the control-plane node, enables it and starts it. The service runs a Python web server on `0.0.0.0:8099` with `Restart=always`. The learner finds the service from the port with `ss -tlnp` and `systemctl status <pid>`, stops it and removes its boot start.

Two outcomes are graded. `listener-closed` needs the unit not running and no TCP listener on port 8099. `boot-start-removed` accepts a `disabled` or `masked` unit file state, or a `not-found` or `masked` load state, so disabling, masking and deleting the unit file all pass. Every outcome also checks that `kubelet` and `containerd` are active on both nodes and that `/readyz` answers `ok`. The lab seeds no Kubernetes workloads; the namespace in `testing/requirements.json` is only the grader's default.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution (`systemctl disable --now`) is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed, `verify-start.sh` failed both outcomes on the starting state, and the commands and output in `solution.md` come from a manual run of the same environment.
