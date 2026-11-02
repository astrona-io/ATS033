---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Privilege Elevation And Account Locking

Some tasks do need administrator rights: restarting a service, reading a protected log, applying an update. The question is how an account receives those rights. Logging in as `root` gives all of them to everyone who knows the password. This part covers `sudo`, which grants chosen commands to chosen accounts, the settings that limit direct `root` and password logins, and the account locks that turn an identity off.

## What sudo does and where its rules live

`sudo` runs one command as another user, normally `root`, after it checks the rule set. The **sudoers** rules are in the file `/etc/sudoers` and in files under `/etc/sudoers.d`. Each rule has four parts: the user or group, the host, the user to run as, and the commands. The tool `visudo` edits these files and checks the syntax before it saves, which matters because a syntax error in the sudoers file can lock every administrator out.

Compare two rules. The first gives full root access, and the second gives one command:

```text
%deployers ALL=(ALL:ALL) NOPASSWD: ALL
%deployers ALL=(root) NOPASSWD: /usr/bin/systemctl restart kubelet.service
```

The first rule lets members of the group `deployers` run any command as any user, without a password. The second rule lets them run only `systemctl restart kubelet.service` as `root`. The second rule is the least-privilege form. Three details make rules weaker than they look. A wildcard in a command argument (`systemctl restart *`) matches more than intended. A command that can start a shell or edit files, such as an editor, a pager or `find`, turns a narrow rule into full root. A rule with `NOPASSWD` removes the second barrier if the account is stolen.

Review who holds which rights with `sudo -l -U <user>`, which lists the commands that a user may run, and with the group membership of the `sudo` group (Debian and Ubuntu) or `wheel` group (Red Hat family). Save narrow rules as separate files in `/etc/sudoers.d`, so each grant has an owner and can be removed by deleting one file. The file name of a rule file must not contain a dot or end with a tilde, because `sudo` skips such files.

## Check what the node has

Select the environment and define the helper:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-01" || exit 1
node_name="astro-ats-033-playground-020-01-control-plane"
run_on_node() { podman exec "$node_name" "$@"; }
```

Check whether `sudo` exists on this node, and list the accounts that have a login shell. `getent passwd` lists all accounts, and the last field is the shell. Accounts with `/usr/sbin/nologin` or `/bin/false` cannot log in interactively:

```sh
run_on_node sh -c 'command -v sudo || echo "sudo is not installed on this node"'
run_on_node getent passwd training-reader
```

If `sudo` is installed, `visudo -c` checks all sudoers files, and `sudo -l -U training-reader` shows what the account may run. The second command shows the account's line from `/etc/passwd`: name, UID, GID, home directory and shell `/bin/sh`.

## Check and change the state of an account

`passwd -S` prints the password status of an account: the name, a status letter (`L` locked, `P` usable password, `NP` no password), the date of the last change and the aging settings. `chage -l` lists the password aging and the account expiry date:

```sh
run_on_node passwd -S training-reader
run_on_node chage -l training-reader
```

Now turn the account off. `usermod --lock` adds a marker to the stored password so that password login fails. `usermod --expiredate 1` sets the expiry to a date in the past, which blocks all authentication methods that go through the account checks. Setting the shell to `nologin` blocks interactive logins:

```sh
run_on_node usermod --lock --expiredate 1 --shell /usr/sbin/nologin training-reader
run_on_node passwd -S training-reader
```

The status letter changes to `L`. Note that a lock marker blocks password logins only. An SSH login with a public key can still work for a locked account unless the expiry date or the shell also blocks it, which is why the command above sets all three. Restore the account so it can be used later in the module:

```sh
run_on_node usermod --unlock --expiredate "" --shell /bin/sh training-reader
run_on_node passwd -S training-reader
```

The status letter returns to its earlier value, and `chage -l` shows the expiry as `never`.

## SSH settings that limit remote access

The SSH daemon `sshd` is the main remote entry to a Linux host, and its configuration is `/etc/ssh/sshd_config`. These settings are the usual hardening baseline:

- `PermitRootLogin no` stops direct logins as `root`, so every action is tied to a named account.
- `PasswordAuthentication no` allows public-key logins only, which removes password guessing.
- `AllowUsers` or `AllowGroups` lists the accounts that may log in at all.
- `MaxAuthTries` lowers the number of attempts per connection.

Check the effective values with `sshd -T`, which prints the configuration that the daemon actually uses, and reload the daemon with `systemctl reload ssh` (Debian family) after a change. A node that needs no remote login at all is better served by removing `sshd`: no daemon means no listener.

## Direct root and shared accounts

Two practices undo the work above. A shared account, such as one `admin` login for a whole team, removes the record of who did what. A direct `root` login does the same and also bypasses the sudo log. Named accounts with narrow `sudo` rules leave a trail in the authentication log, which the last part of this module reads.

You can now judge a sudoers rule, check an account's state, and turn an identity off without deleting it. The node is only half of the cluster's identities. The Kubernetes API has its own accounts and its own permission model, which the next part covers.

## Common pitfalls

> [!WARNING]
> - **Editing sudoers with a normal editor.** A syntax error can lock out every administrator. Use `visudo`, or `visudo -cf <file>` to check a file first.
> - **Granting a command that opens a shell.** Editors, pagers and `find` can start a shell, so a rule for them gives full root.
> - **Locking only the password.** `usermod --lock` does not stop key-based SSH logins. Also set an expiry date or a `nologin` shell.
> - **Using wildcards in command arguments.** `systemctl restart *` also matches arguments you did not plan for. Name the exact command.
