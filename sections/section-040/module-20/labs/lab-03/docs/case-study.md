---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-02-03` holds the Deployment `shuttle` with one replica. Its container runs a shell loop: it writes the date to `/tmp/manifest.new`, renames that file to `/tmp/manifest` with `mv`, and stops with an error when a step fails. A readiness probe reads `/tmp/manifest`.

The pod template uses the `Localhost` seccomp profile `profiles/cargo-guard.json`. The file is installed on the node in the kubelet seccomp directory, `/var/lib/kubelet/seccomp`. The profile blocks one group of system calls that the workload needs, so the container fails and the kubelet keeps restarting it.

The security team requires that the workload can never change the owner of a file. The profile must keep blocking the system calls that do that.
