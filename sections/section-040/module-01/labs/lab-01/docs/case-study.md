---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Create Pod `restricted-reader` running BusyBox as user and group 1000, with `runAsNonRoot: true`, RuntimeDefault seccomp and group-writable emptyDir `scratch` mounted at `/scratch`. Its container must disable privilege escalation, drop all capabilities and use a read-only root filesystem. Writing in scratch must work; writing `/root-file` must fail. Keep the sleeping process running.
