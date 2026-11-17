---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The cluster has one control-plane node and one worker node. The start of the lab has checked that AppArmor is enabled in the kernel of both nodes. It has saved the profile `k8s-deny-tmp-write` as `/etc/apparmor.d/k8s-deny-tmp-write` in each node and loaded it in enforce mode. The profile allows file access, network access and capabilities, and has one rule, `deny /tmp/** w`, that blocks every write under `/tmp`.

The pod `bridge` in `starfleet-033-040-03-02` sets `appArmorProfile` type `Localhost` with `k8s-deny-tmp-write` in the pod `securityContext`. A value there applies to every container that does not set its own value.

The container `console` writes the date to `/tmp/console.log` every five seconds and stops with exit code 1 when the write fails. Its readiness probe reads that file. The container `logger` runs `sleep 3600`. The start of the lab waited until `console` had restarted at least once.
