---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The cluster has one control-plane node and one worker node. The start of the lab has checked that AppArmor is enabled in the kernel of both nodes. It has saved the profile `k8s-deny-etc-write` as `/etc/apparmor.d/k8s-deny-etc-write` in each node and loaded it with `apparmor_parser -r -C`, which means complain mode.

The profile allows the program to read and run every file, and to write only under `/dev`, `/proc`, `/run`, `/tmp` and `/var`. No rule allows a write under `/etc`. In complain mode the kernel allows such a write and only logs it.

The Deployment `scout` in `starfleet-033-040-03-01` has one replica. Its container `scout` runs `sleep 3600` and selects the profile with `appArmorProfile` type `Localhost`.
