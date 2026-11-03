---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Summary

A login to a node gives a shell on the machine that runs every pod of that node, so each login path is part of the cluster's security boundary. The SSH daemon `sshd` decides which logins it accepts, and it reads its settings from a main file that can include drop-in files. For each keyword the daemon uses the first value it reads. A drop-in file that is read before the main file can therefore override a value that looks correct in the main file. The most reliable check is the effective configuration that `sshd -T` prints on a host that has the daemon.

Key-only access means `PasswordAuthentication no` and `PubkeyAuthentication yes`, with keyboard-interactive authentication checked as well. `PermitRootLogin no` refuses the root account, and administrators use a named account and `sudo`. `AllowUsers` or `AllowGroups` states who may log in, and an account that is not listed is refused even with a valid key. A `Match` block changes the meaning of every line after it, so global settings belong above the first `Match` line.

A change to a live daemon needs care. The administrator checks the syntax with `sshd -t`, reloads the daemon so open sessions stay alive, and tests a new login from a second session before closing the first.

Accounts add login paths of their own. The seventh field of `/etc/passwd` is the login shell, and `/usr/sbin/nologin` refuses an interactive login. A locked password, a refusing shell and the removal of `authorized_keys` each close a different credential, and all three are needed. An account with UID 0 is root whatever its name. Locking an account keeps its files traceable, and deleting it comes only after review.

Key facts:

- The first value of an SSH keyword wins.
- A `nologin` shell, a locked password and removed keys close three different paths.
- `AllowUsers` limits SSH logins only; it does not change the account.
- Reload the daemon instead of restarting it, and test from a second session.

<!-- astrona:playground:destroy -->
