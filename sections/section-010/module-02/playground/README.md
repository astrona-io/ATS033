# Hardening Node Access Playground

This ungraded playground runs one VM from the pinned `24.04-cks` QEMU image (`ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`). `bootstrap/setup.sh` runs in the VM as the `astrona` user: it builds a one-node kubeadm cluster (Kubernetes v1.35.10), gives `student` the admin kubeconfig, seeds the `starfleet` and `outpost` workloads, writes `PasswordAuthentication yes` to `/etc/ssh/sshd_config.d/50-cloud-init.conf`, appends `PermitRootLogin yes`, `PasswordAuthentication no` and a `Match User backup` block to `/etc/ssh/sshd_config`, reloads `ssh.service`, and creates `opsadmin` and `olduser` (with a password and an SSH public key).

The guide is `docs/overview.md`. The configuration has no submission or grading fields. Learners connect with `astrona ssh astro-ats-033-playground-010-02`. The guided practice keeps `student` and `astrona` in `AllowUsers`, so the platform keeps its SSH access.

Live runs on 2026-11-18 (QEMU, arm64, hvf): the second `astrona run` finished in 33 seconds (VM SSH-ready 15 s, seed 18 s). The output in `docs/overview.md` and in the module readings was captured in that VM as `student`. `scripts/ci/test-playground.sh` supports only kind playgrounds, because `astrona kubeconfig` works only for kind, so it does not cover this playground.
