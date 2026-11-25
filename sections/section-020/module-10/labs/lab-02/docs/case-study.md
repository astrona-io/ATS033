---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster runs in one virtual machine, and that machine is its only node. It has no application workloads. The node has two normal accounts with a password: `departed-user` and `pilot`. Both accounts use the shell `/bin/bash` and never expire.

The SSH daemon (sshd) reads an extra file, `/etc/ssh/sshd_config.d/10-migration-access.conf`, that allows logins as `root` and logins with a password.

`departed-user` belongs to a person who has left. The task is to disable that account without deleting it, to close `root` and password logins in sshd, and to leave `pilot` unchanged.
