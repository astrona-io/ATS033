---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close An Unneeded Listener On A Node

The setup script installs `remote-diag.service` in `/usr/lib/systemd/system` on the lab VM, enables it and starts it. The service runs a Python web server on `0.0.0.0:8099` with `Restart=always`. The learner finds the service from the port with `ss -tlnp` and `systemctl status <pid>`, stops it and removes its boot start.

Two outcomes are graded. `listener-closed` needs the unit not running and no TCP listener on port 8099. `boot-start-removed` accepts a `disabled` or `masked` unit file state, or a `not-found` or `masked` load state, so disabling, masking and deleting the unit file all pass. Every outcome also checks that `kubelet` and `containerd` are active and that `/readyz` answers `ok`. The lab seeds no Kubernetes workloads; the namespace in `testing/requirements.json` is only the grader's default.

The task and solution use a VM from the pinned `24.04-cks` image with a one-node kubeadm cluster (Kubernetes v1.35.10). `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` (`systemctl disable --now`) applies the reference solution and every outcome must pass.

Live run on 2026-11-18 (QEMU, `24.04-cks` image, Kubernetes v1.35.10): `astrona test` reached `PROCTOR: PASS` (2/2), `verify-start.sh` failed both outcomes on the starting state, and the commands and output in `solution.md` come from a manual run in the same VM image, followed by `astrona submit` with `PROCTOR: PASS`.
