# Reducing The Host Operating-System Attack Surface Playground

This ungraded playground runs one VM from the pinned `24.04-cks` QEMU image (`ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-20261118-{ARCH}`). `bootstrap/setup.sh` runs in the VM as the `astrona` user: it builds a one-node kubeadm cluster (Kubernetes v1.35.10) with `/usr/local/sbin/astrona-kubeadm-init`, gives `student` the admin kubeconfig, seeds the `starfleet` and `outpost` workloads, installs and starts `training-extra.service` in `/etc/systemd/system`, and installs the `node-diag-tools` package (`/usr/bin/node-diag`). The image itself ships `ModemManager.service` enabled, which the readings mask.

The guide is `docs/overview.md`. The configuration has no submission or grading fields. Learners connect with `astrona ssh astro-ats-033-playground-010-01`.

Live runs on 2026-11-18 (QEMU, arm64, hvf): `astrona run` finished in 34 seconds on the first run and in about 70 seconds on the second (VM SSH-ready 15 s, seed 54 s). The output in `docs/overview.md` and in the module readings was captured in that VM as `student`. `scripts/ci/test-playground.sh` supports only kind playgrounds, because `astrona kubeconfig` works only for kind, so it does not cover this playground.
