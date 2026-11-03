---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The control-plane node of this environment holds a stand-in SSH server configuration in `/etc/ssh/sshd_config`, a drop-in file `/etc/ssh/sshd_config.d/50-cloud-init.conf`, and two accounts: `opsadmin`, the account that administrators use, and `olduser`, an account nobody uses any more. The setup script writes the files itself, so the exercise does not depend on an SSH server being installed in the node image. Today root may log in over SSH, the first `PasswordAuthentication` value that the daemon reads allows passwords, any account may log in, and `olduser` has the shell `/bin/bash`.
