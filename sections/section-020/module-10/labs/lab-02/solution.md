---
exam_objectives:
- Using least-privilege identity and access management
---
# Lock And Expire A Departed Account Solution

Open a shell on the lab VM. The VM is the only node of the cluster, so every command below runs on the node itself and changes only this lab.

```sh
astrona ssh astro-ats-033-lab-020-01-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-020-01-02
```

You are logged in as `student`. This user may run any command as `root` through `sudo`, which the steps below need to change accounts and the SSH server configuration.

## 1. Inspect the account

Three settings decide whether an account can still start a session: the password status, the account expiry date and the login shell. `passwd -S` prints the password status, `chage -l` prints the dates and `getent passwd` prints the passwd entry with the shell.

```sh
sudo passwd -S departed-user
sudo chage -l departed-user
getent passwd departed-user
```

```text
departed-user P 2026-11-18 0 99999 7 -1
Last password change					: Nov 18, 2026
Password expires					: never
Password inactive					: never
Account expires						: never
Minimum number of days between password change		: 0
Maximum number of days between password change		: 99999
Number of days of warning before password expires	: 7
departed-user:x:1003:1003::/home/departed-user:/bin/bash
```

The second field `P` means the account has a usable password. The account never expires, and the shell is `/bin/bash`. Your dates and IDs can differ. A test with `su` confirms that `root` can still start a shell as this account:

```sh
sudo su -s /bin/sh -c 'id -un' departed-user
```

```text
departed-user
```

## 2. Lock the password

`usermod --lock` puts a `!` in front of the password hash in `/etc/shadow`. No password can match that hash any more.

```sh
sudo usermod --lock departed-user
sudo passwd -S departed-user
sudo su -s /bin/sh -c 'id -un' departed-user
```

```text
departed-user L 2026-11-18 0 99999 7 -1
departed-user
```

The status is now `L`. The `su` command from `root` still works, because `root` does not need the password. A lock stops password logins only. Other ways in, such as an SSH key or a process started by `root`, are not blocked by the lock.

## 3. Expire the account

`usermod --expiredate 1` sets the expiry field to day 1 after 1 January 1970. The PAM (Pluggable Authentication Modules) account check refuses an expired account for every login method, including `su` from `root`.

```sh
sudo usermod --expiredate 1 departed-user
sudo chage -l departed-user
sudo su -s /bin/sh -c 'id -un' departed-user
```

```text
Last password change					: Nov 18, 2026
Password expires					: never
Password inactive					: never
Account expires						: Jan 02, 1970
Minimum number of days between password change		: 0
Maximum number of days between password change		: 99999
Number of days of warning before password expires	: 7
Your account has expired; please contact your system administrator.
su: Authentication failure
```

The account expiry date is in the past, and PAM now refuses the session.

## 4. Remove the login shell

`usermod --shell /usr/sbin/nologin` replaces the shell. If a login ever passes the other checks, `nologin` prints a message and exits instead of starting a shell.

```sh
sudo usermod --shell /usr/sbin/nologin departed-user
getent passwd departed-user
```

```text
departed-user:x:1003:1003::/home/departed-user:/usr/sbin/nologin
```

## 5. Close root and password logins in sshd

The account is now closed, but the SSH server still accepts logins that the team does not want. sshd is the SSH daemon, the process that accepts SSH logins. `sshd -T` reads every configuration file and prints the settings sshd would use:

```sh
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication) '
ls /etc/ssh/sshd_config.d
grep -n -i include /etc/ssh/sshd_config
```

```text
permitrootlogin yes
passwordauthentication yes
10-migration-access.conf
50-cloud-init.conf
60-cloudimg-settings.conf
12:Include /etc/ssh/sshd_config.d/*.conf
```

Line 12 of `/etc/ssh/sshd_config` reads the drop-in files in `/etc/ssh/sshd_config.d` in name order. For most settings, sshd uses the first value it reads. So `10-migration-access.conf` wins over the `PasswordAuthentication no` in `50-cloud-init.conf`. Look at the file:

```sh
sudo cat /etc/ssh/sshd_config.d/10-migration-access.conf
```

```text
# Temporary access for the migration team
PermitRootLogin yes
PasswordAuthentication yes
```

The running daemon shows the same thing. A login attempt with `BatchMode=yes` sends no password. The server then lists the methods it offers:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR pilot@127.0.0.1 true
```

```text
pilot@127.0.0.1: Permission denied (publickey,password).
```

The server offers `password`. Remove the old file and check again:

```sh
sudo rm /etc/ssh/sshd_config.d/10-migration-access.conf
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication) '
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR pilot@127.0.0.1 true
```

```text
permitrootlogin without-password
passwordauthentication no
pilot@127.0.0.1: Permission denied (publickey,password).
```

This output shows two separate problems. First, `sshd -T` reads the files, but the running daemon still offers `password`: it keeps its old settings until it is reloaded. Second, the image default `without-password` still lets `root` log in with a key, and the task asks for `no`.

Write your own drop-in file. A low number such as `10-` makes sure sshd reads it first. Save this as `10-hardening.conf` in your home directory, for example with `nano 10-hardening.conf`:

```text
PermitRootLogin no
PasswordAuthentication no
```

Install it, test the configuration with `sshd -t` and reload the service. `sshd -t` prints nothing when the files are valid. Always run it before a reload, because a broken file can stop new SSH logins.

```sh
sudo install -m 0644 10-hardening.conf /etc/ssh/sshd_config.d/10-hardening.conf
sudo sshd -t
sudo systemctl reload ssh
```

Then check the result in the files and in the running daemon:

```sh
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication) '
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR pilot@127.0.0.1 true
systemctl is-active ssh
```

```text
permitrootlogin no
passwordauthentication no
pilot@127.0.0.1: Permission denied (publickey).
active
```

The files say `no` for both settings. The running daemon now offers only `publickey`, and the service is still active.

## 6. Confirm that pilot is unchanged

```sh
sudo passwd -S pilot
getent passwd pilot
```

```text
pilot P 2026-11-18 0 99999 7 -1
pilot:x:1004:1004::/home/pilot:/bin/bash
```

`pilot` still has a usable password and its shell. Submit with `astrona submit`. When you are done, leave the VM with `exit` and remove the lab with `astrona destroy ats-033-lab-020-01-02`.

## Common pitfalls

> [!WARNING]
> - **Locking only the password.** A locked password does not stop key-based logins or `su` from `root`. Expire the account too.
> - **Using `chage -E 0`.** Day 0 also works on most systems, but some tools treat `0` in a special way. A date such as `1` or `1970-01-02` is clear.
> - **Deleting the account.** `userdel` removes the account and can reuse its UID later, so old files can end up owned by a new account. Disable the account when an audit needs it.
> - **Editing a file sshd reads later.** sshd uses the first value it reads. A setting in `/etc/ssh/sshd_config` after the `Include` line, or in a drop-in with a higher number, does not override an earlier one. Check the result with `sshd -T`.
> - **Forgetting the reload.** `sshd -T` shows the files, not the running daemon. Run `sshd -t`, then `systemctl reload ssh`, and test with a real login attempt.
