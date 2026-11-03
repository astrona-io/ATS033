---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The cluster has one control-plane node and one worker node. Each node is a Podman container that runs systemd. The `starfleet` namespace runs the `probe` application, the `beacon` Deployment and the `ledger` Deployment. The `outpost` namespace runs the `drifter` pod.

Four faults exist. The control-plane node runs `training-extra.service`, which is enabled and has no job. The worker node holds a stand-in SSH server configuration in `/etc/ssh/sshd_config` and `/etc/ssh/sshd_config.d/50-cloud-init.conf` that allows root and password logins and allows any account, and it has an unused account `olduser` with the shell `/bin/bash` next to the administrator account `opsadmin`. The `beacon` pod template uses `hostNetwork`, `hostPID`, a privileged container and a `hostPath` volume of `/var/log`. The `ledger` Deployment handles sensitive data but runs wherever the scheduler places it, and the worker node has no label or taint for it.
