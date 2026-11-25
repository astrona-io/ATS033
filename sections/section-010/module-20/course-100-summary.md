# Summary

A login to a node gives a shell on the machine that runs every pod of that node. So each login path is part of the security boundary of the cluster.

The SSH daemon `sshd` decides which logins it accepts. It reads its settings from a main file that can include drop-in files. For each keyword, the daemon uses the first value it reads. A drop-in file that the daemon reads before the main file can therefore override a value that looks correct in the main file. The most reliable check is the effective configuration that `sshd -T` prints. It reads the files from disk, so the running daemon uses a change only after `systemctl reload`.

Key-only access means `PasswordAuthentication no` and `PubkeyAuthentication yes`, and keyboard-interactive authentication needs a check as well. `PermitRootLogin no` refuses the root account, and administrators use a named account and `sudo`. `AllowUsers` or `AllowGroups` states who may log in, and the daemon refuses an account that is not listed, even with a valid key. A `Match` block changes the meaning of every line after it. Global settings therefore belong above the first `Match` line, or in a drop-in file that the `Include` line reads.

A change to a running daemon needs care. The administrator checks the syntax with `sshd -t` and reloads the daemon, so that open sessions stay alive. Then the administrator tests a new login from a second session before closing the first.

Accounts add login paths of their own. The seventh field of `/etc/passwd` is the login shell, and `/usr/sbin/nologin` refuses an interactive login. A refusing shell, a locked password and the removal of `authorized_keys` each close a different credential, and all three are needed. An account with user identifier (UID) 0 is root, whatever its name. Locking an account keeps its files traceable, and deleting it comes only after a review of those files.

Key facts to remember:

- The first value of an SSH keyword wins.
- A `nologin` shell, a locked password and removed keys close three different paths.
- `AllowUsers` limits SSH logins only; it does not change the account.
- Reload the daemon instead of restarting it, and test from a second session.

<!-- astrona:playground:destroy -->
