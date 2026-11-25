---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close Unused And Duplicate Root Accounts Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-02-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run commands that read passwords or change accounts with `sudo`. They change only the lab VM, not your own computer.

## Review the accounts

Each line of `/etc/passwd` has seven fields separated by colons: the name, a password placeholder, the UID, the group identifier (GID), a description, the home directory and the login shell. `getent passwd` reads the account database the way the system does. The `awk` filter prints the name, the UID and the shell of every account whose shell is not a refusing shell:

```sh
getent passwd | awk -F: '$7 !~ /(nologin|false)$/ {print $1 ":" $3 ":" $7}'
```

```text
root:0:/bin/bash
sync:4:/bin/sync
ubuntu:1000:/bin/bash
student:1001:/bin/bash
astrona:1002:/bin/bash
opsadmin:1003:/bin/bash
olduser:1004:/bin/bash
toor:0:/bin/bash
```

`sync` is a system account whose shell is `/bin/sync`, a program that writes the disk buffers and ends, so it cannot start a session. `ubuntu` is the default account of the cloud image, and `student` and `astrona` are the accounts the lab platform logs in with. `olduser` has `/bin/bash`, and `toor` has UID 0. A second check lists every account with UID 0, because the kernel checks the number and not the name:

```sh
awk -F: '$3 == 0 {print $1}' /etc/passwd
```

```text
root
toor
```

`passwd -S` prints the password status of one account. It reads `/etc/shadow`, which only root can read, so it needs `sudo`. The second field is `P` for a usable password, `L` for a locked password and `NP` for no password:

```sh
sudo passwd -S olduser
sudo passwd -S opsadmin
```

```text
olduser P 2026-11-18 0 99999 7 -1
opsadmin P 2026-11-18 0 99999 7 -1
```

Both accounts have a usable password. Your date will be the day the environment started.

## Close olduser

`usermod --shell` changes the seventh field of the account, and `--lock` puts an exclamation mark in front of the password hash in `/etc/shadow`, so no password can match it. One command does both:

```sh
sudo usermod --shell /usr/sbin/nologin --lock olduser
getent passwd olduser
sudo passwd -S olduser
```

```text
olduser:x:1004:1004::/home/olduser:/usr/sbin/nologin
olduser L 2026-11-18 0 99999 7 -1
```

The shell is now `/usr/sbin/nologin` and the status is `L`. `su` starts the shell of the target account, so it shows the effect of the new shell:

```sh
sudo su olduser -c true
```

```text
This account is currently not available.
```

`nologin` prints this message and exits with status 1. The account and its home directory stay, so files that belong to UID 1004 still show the name `olduser`.

## Remove the second UID 0 account

The first attempt with `userdel` fails:

```sh
sudo userdel toor
```

```text
userdel: user toor is currently used by process 1
```

`userdel` refuses to delete an account while a process runs with its UID. Process 1 is `systemd`, which runs as UID 0, the same number that `toor` has. The process belongs to `root`, not to `toor`, so deleting the `toor` entry is safe. The option `--force` tells `userdel` to go on despite the running process:

```sh
sudo userdel --force toor
```

```text
userdel: user toor is currently used by process 1
```

With `--force`, the same message is only a warning, and the command exits with status 0. Do not add `--remove`: it deletes the home directory, and a hidden root account often points at `/root`. Here `toor` has the home directory `/nonexistent`.

## Verify the result

Check the UID 0 accounts, the administrator account and the node services that Kubernetes needs:

```sh
awk -F: '$3 == 0 {print $1}' /etc/passwd
getent passwd root
sudo passwd -S opsadmin
systemctl is-active kubelet.service containerd.service
kubectl get --raw=/readyz; echo
```

```text
root
root:x:0:0:root:/root:/bin/bash
opsadmin P 2026-11-18 0 99999 7 -1
active
active
ok
```

Only `root` has UID 0, its entry is unchanged, and `opsadmin` keeps a usable password. `kubelet` and `containerd` are `active`, and the API server answers `ok`. Then submit.

## Common pitfalls

> [!WARNING]
> - **Locking only the password.** A locked password does not stop a login with an SSH key. Set the `nologin` shell as well.
> - **Searching for root by name.** The kernel checks the UID. Look for every account with UID 0.
> - **`userdel --remove` on a UID 0 account.** If the account points at `/root`, the command deletes the home directory of `root`.
> - **Locking `opsadmin` by mistake.** Check the account name in every command. Administrators then lose access to the node.
