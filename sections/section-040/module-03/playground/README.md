# Drop Capabilities And Block Escalation Playground

This ungraded environment is a VM (virtual machine) from the pinned `24.04-cks` image. It runs a one-node kubeadm cluster with Kubernetes v1.35.10 and containerd 2.2.1, and its kernel has AppArmor enabled. A kind node uses the kernel of the machine that runs Podman, which often has no AppArmor, so the module readings use this VM instead.

`bootstrap/setup.sh` runs inside the VM. It builds the cluster with `astrona-kubeadm-init` for the `astrona` and `student` users, checks the context `kubernetes-admin@astro-ats-033-playground-040-03`, and creates the `starfleet` and `outpost` namespaces with the `probe` Deployment and Service and the `shuttle` and `drifter` pods. `validate.sh` refuses any other context. The configuration has no submission or grading fields.

The learner works in the VM with `astrona ssh astro-ats-033-playground-040-03` as `student`, and runs node commands with `sudo`.

Runtime verification on 2026-11-18 (arm64): `astrona validate` passed and `astrona run --accept-terms --headless` reached "Lab environment is fully loaded and ready!" in about 68 seconds. Every command in the module readings and `docs/overview.md` was run in the VM, and the quoted output comes from that run. `scripts/ci/test-playground.sh` does not support this playground, because it reads a kind kubeconfig with `astrona kubeconfig`.
