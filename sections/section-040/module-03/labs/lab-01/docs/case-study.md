---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The cluster has one node, `astro-ats-033-lab-040-03-01`, which is the control plane and also runs the pods. Its kernel has AppArmor enabled. The start of the lab has saved the profile `k8s-deny-etc-write` as `/etc/apparmor.d/k8s-deny-etc-write` and loaded it with `apparmor_parser -r -C`, which means complain mode.

The profile allows the program to read and run every file, and to write only under `/dev`, `/proc`, `/run`, `/tmp` and `/var`. No rule covers a write under `/etc`, and the profile has no `deny` rule. In complain mode the kernel allows such an uncovered write and logs it.

The Deployment `scout` in `starfleet-033-040-03-01` has one replica. Its container `scout` runs `sleep 3600` and selects the profile with `appArmorProfile` type `Localhost`.
