---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The Deployment `relay` in `starfleet-033-040-03-01` was started with `privileged: true` and escalation allowed, as root, with the full set of capabilities. The only privileged operation it ever needs is listening on a port below 1024.

Change Deployment `relay` in `starfleet-033-040-03-01` and keep its name, selector, image and command. Its pod must set `runAsNonRoot: true`, `runAsUser: 1000` and `RuntimeDefault` seccomp. Its container `relay` must set `privileged: false` and `allowPrivilegeEscalation: false`, drop `ALL` capabilities and add back only `NET_BIND_SERVICE`. The running pod must show `CapBnd` as `0000000000000400`, `NoNewPrivs: 1` and `Seccomp: 2` in `/proc/1/status`, and the Deployment rollout must be complete.
