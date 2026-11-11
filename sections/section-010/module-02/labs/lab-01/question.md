---
draft: true
---
# Harden A Running SSH Service

Solve this question on: `terminal`

Connect with `astrona ssh ats-033-lab-010-02-01`. This Ubuntu VM has a separate `training-sshd` service on `127.0.0.1:2222`. Its configuration is `/etc/ssh/sshd_config.training`. The VM access listener on port 22 is outside the task. The supplied lab key is `/opt/training-ssh/client`; both training accounts initially have the disposable password `training-password`.

Allow about 15 minutes for the tasks. VM startup and package installation add time.

## Tasks

1. Disable root authentication on the training listener and prove a fresh root key login is refused.
2. Disable password authentication while preserving a successful `opsadmin` key login. Validate the configuration and reload `training-sshd`.
3. Allow only `opsadmin` on that listener. Lock `olduser`'s password and set its shell to `/usr/sbin/nologin`; prove its key no longer permits login.

## Constraints

Keep the training service and administrator key working. Preserve the VM access service, the supplied key and all files under `/opt/astrona-live`. Apply changes to the separate training configuration, not port 22.

## How the answer is checked

Fresh SSH connections test allowed key login and denied root, password and olduser authentication. Connection failures do not count as authentication refusals. The grader also checks the account state and effective AllowUsers configuration.
