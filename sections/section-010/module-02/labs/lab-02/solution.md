---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close Unused And Duplicate Root Accounts Solution

Select the private environment and define a helper. The helper `run_on_node` runs one command on the control-plane node container, which is the same as running it as root in a shell on the node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-02" || exit 1
node_name="astro-ats-033-lab-010-02-02-control-plane"
worker_name="astro-ats-033-lab-010-02-02-worker"
run_on_node() { podman exec "$node_name" "$@"; }
```

## Review the accounts

Each line of `/etc/passwd` has seven fields separated by colons: the name, a password placeholder, the UID, the group identifier (GID), a description, the home directory and the login shell. `getent passwd` reads the account database the way the system does. The `awk` filter prints the name, the UID and the shell of every account whose shell is not a refusing shell:

```sh
run_on_node sh -c "getent passwd | awk -F: '\$7 !~ /(nologin|false)\$/ {print \$1 \":\" \$3 \":\" \$7}'"
```

```text
root:0:/bin/bash
sync:4:/bin/sync
opsadmin:1000:/bin/bash
olduser:1001:/bin/bash
toor:0:/bin/bash
```

`sync` is a system account whose shell is `/bin/sync`, a program that writes the disk buffers and ends, so it cannot start a session. `olduser` has `/bin/bash`, and `toor` has UID 0. A second check lists every account with UID 0, because the kernel checks the number and not the name:

```sh
run_on_node sh -c "awk -F: '\$3 == 0 {print \$1}' /etc/passwd"
```

```text
root
toor
```

`passwd -S` prints the password status of one account. The second field is `P` for a usable password, `L` for a locked password and `NP` for no password:

```sh
run_on_node passwd -S olduser
run_on_node passwd -S opsadmin
```

```text
olduser P 2026-11-17 0 99999 7 -1
opsadmin P 2026-11-17 0 99999 7 -1
```

Both accounts have a usable password. Your date will be the day the environment started.

## Close olduser

`usermod --shell` changes the seventh field of the account, and `--lock` puts an exclamation mark in front of the password hash in `/etc/shadow`, so no password can match it. One command does both:

```sh
run_on_node usermod --shell /usr/sbin/nologin --lock olduser
run_on_node getent passwd olduser
run_on_node passwd -S olduser
```

```text
olduser:x:1001:1001::/home/olduser:/usr/sbin/nologin
olduser L 2026-11-17 0 99999 7 -1
```

The shell is now `/usr/sbin/nologin` and the status is `L`. The account and its home directory stay, so files that belong to UID 1001 still show the name `olduser`.

## Remove the second UID 0 account

The first attempt with `userdel` fails:

```sh
run_on_node userdel toor
```

```text
userdel: user toor is currently used by process 1
```

`userdel` refuses to delete an account while a process runs with its UID. Process 1 is `systemd`, which runs as UID 0, the same number that `toor` has. The process belongs to `root`, not to `toor`, so deleting the `toor` entry is safe. The option `--force` tells `userdel` to go on despite the running process:

```sh
run_on_node userdel --force toor
```

```text
userdel: user toor is currently used by process 1
```

With `--force`, the same message is only a warning, and the command exits with status 0. Do not add `--remove`: it deletes the home directory, and a hidden root account often points at `/root`. Here `toor` has the home directory `/nonexistent`.

## Verify the result

Check the UID 0 accounts, the administrator account and the node services that Kubernetes needs:

```sh
run_on_node sh -c "awk -F: '\$3 == 0 {print \$1}' /etc/passwd"
run_on_node getent passwd root
run_on_node passwd -S opsadmin
run_on_node systemctl is-active kubelet.service containerd.service
```

```text
root
root:x:0:0:root:/root:/bin/bash
opsadmin P 2026-11-17 0 99999 7 -1
active
active
```

Only `root` has UID 0, its entry is unchanged, and `opsadmin` keeps a usable password. Then submit.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-010-02-02`.

## Common pitfalls

> [!WARNING]
> - **Locking only the password.** A locked password does not stop a login with an SSH key. Set the `nologin` shell as well.
> - **Searching for root by name.** The kernel checks the UID. Look for every account with UID 0.
> - **`userdel --remove` on a UID 0 account.** If the account points at `/root`, the command deletes the home directory of `root`.
> - **Locking `opsadmin` by mistake.** Check the account name in every command. Administrators then lose access to the node.
