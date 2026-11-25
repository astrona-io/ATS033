# Least Privilege For Host Identities And Administration Playground

This ungraded environment runs on the CKS QEMU image (`24.04-cks`): one VM that is a one-node kubeadm cluster. `bootstrap/setup.sh` starts the cluster, deploys the `starfleet` workloads and seeds the `training-reader` account, the `training-readers` group and the two report files. The configuration has no submission or grading fields.

Verification on 2026-11-18 (arm64, hvf): `astrona validate -c` passed. `astrona run` finished in about 70 seconds (VM SSH-ready 15s, seed 47-55s). The commands of `docs/overview.md` and of the module readings were run in the VM, and their output on those pages is the captured output. `scripts/ci/test-playground.sh` starts the VM, copies the module pages, `docs/` and `testing/` into it over SSH and runs `testing/smoke.sh` there as `student`.
