---
exam_objectives:
- Using least-privilege identity and access management
---
# Lock And Expire A Departed Account Solution

Select the private cluster and define a small helper. The helper `run_on_node` runs one command inside the control-plane node container, so every command below changes only this lab's node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-02" || exit 1
node_name="astro-ats-033-lab-020-01-02-control-plane"
run_on_node() { podman exec "$node_name" "$@"; }
```

## 1. Inspect the account

Three settings decide whether an account can still start a session: the password status, the account expiry date and the login shell. `passwd -S` prints the password status, `chage -l` prints the dates and `getent passwd` prints the passwd entry with the shell.

```sh
run_on_node passwd -S departed-user
run_on_node chage -l departed-user
run_on_node getent passwd departed-user
```

```text
departed-user P 2026-11-17 0 99999 7 -1
Last password change					: Nov 17, 2026
Password expires					: never
Password inactive					: never
Account expires						: never
Minimum number of days between password change		: 0
Maximum number of days between password change		: 99999
Number of days of warning before password expires	: 7
departed-user:x:1002:1003::/home/departed-user:/bin/bash
```

The second field `P` means the account has a usable password. The account never expires, and the shell is `/bin/bash`. Your dates and IDs can differ. A test with `su` confirms that root can still start a shell as this account:

```sh
run_on_node su -s /bin/sh -c 'id -un' departed-user
```

```text
departed-user
```

## 2. Lock the password

`usermod --lock` puts a `!` in front of the password hash in `/etc/shadow`. No password can match that hash any more.

```sh
run_on_node usermod --lock departed-user
run_on_node passwd -S departed-user
run_on_node su -s /bin/sh -c 'id -un' departed-user
```

```text
departed-user L 2026-11-17 0 99999 7 -1
departed-user
```

The status is now `L`. The `su` command from root still works, because root does not need the password. A lock stops password logins only. Other ways in, such as an SSH key or a process started by root, are not blocked by the lock.

## 3. Expire the account

`usermod --expiredate 1` sets the expiry field to day 1 after 1 January 1970. The PAM (Pluggable Authentication Modules) account check refuses an expired account for every login method, including `su` from root.

```sh
run_on_node usermod --expiredate 1 departed-user
run_on_node chage -l departed-user
run_on_node su -s /bin/sh -c 'id -un' departed-user
```

```text
Last password change					: Nov 17, 2026
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
run_on_node usermod --shell /usr/sbin/nologin departed-user
run_on_node getent passwd departed-user
```

```text
departed-user:x:1002:1003::/home/departed-user:/usr/sbin/nologin
```

## 5. Confirm that pilot is unchanged

```sh
run_on_node passwd -S pilot
run_on_node getent passwd pilot
```

```text
pilot P 2026-11-17 0 99999 7 -1
pilot:x:1003:1004::/home/pilot:/bin/bash
```

`pilot` still has a usable password and its shell. Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-01-02`.

## Common pitfalls

> [!WARNING]
> - **Locking only the password.** A locked password does not stop key-based logins or `su` from root. Expire the account too.
> - **Using `chage -E 0`.** Day 0 also works on most systems, but some tools treat `0` in a special way. A date such as `1` or `1970-01-02` is clear.
> - **Deleting the account.** `userdel` removes the account and can reuse its UID later, so old files can end up owned by a new account. Disable the account when an audit needs it.
> - **Locking the wrong account.** Check the name before you run `usermod`. The grader checks that `pilot` keeps working.
