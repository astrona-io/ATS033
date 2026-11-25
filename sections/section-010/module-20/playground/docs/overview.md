---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Guided Practice: Harden SSH Access And Unused Accounts

This playground is one Ubuntu 24.04 virtual machine (VM). kubeadm installed Kubernetes v1.35.10 on it as a single node. The node runs a real SSH daemon, `sshd`, and an old image build left settings that allow root logins and password logins. It also left an account, `olduser`, that nobody uses. In this practice you close those login paths and prove that the node still works.

Open a shell on the VM and confirm that `kubectl` points at this playground:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-010-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-playground-010-02
```

You are logged in as the `student` user, which has a kubeconfig file for the cluster. The SSH files and the account database belong to root, so commands that read or change them start with `sudo`. Keep this shell open until the end: if a change blocks new logins, you can still repair it from here.

## Read the effective SSH settings

`sshd` reads the main file `/etc/ssh/sshd_config`, and its `Include` line reads the drop-in files in `/etc/ssh/sshd_config.d/` first. For most keywords the first value wins. `sshd -T` prints the effective value of every keyword after the daemon applied this rule:

```sh
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers) '
sudo grep -H . /etc/ssh/sshd_config.d/50-cloud-init.conf
```

```text
permitrootlogin yes
pubkeyauthentication yes
passwordauthentication yes
/etc/ssh/sshd_config.d/50-cloud-init.conf:PasswordAuthentication yes
```

Root and password logins are allowed, and there is no `allowusers` line, so every account may log in. The `yes` for passwords comes from the drop-in file. `PermitRootLogin yes` comes from the main file, and no drop-in file sets it.

## Fix the settings and reload the daemon

Change the line that is read first for each keyword. Then add the allow list in its own drop-in file. A drop-in file is read above the `Match User backup` block at the end of the main file, so its lines are global. The list must contain `student` and `astrona`, the accounts the platform uses:

```sh
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowUsers opsadmin student astrona" | sudo tee /etc/ssh/sshd_config.d/10-allow-users.conf
```

```text
AllowUsers opsadmin student astrona
```

`sshd -t` checks the syntax of all files and prints nothing when they are valid. `systemctl reload` makes the running daemon read its files again and keeps open sessions:

```sh
sudo sshd -t
sudo systemctl reload ssh.service
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|allowusers) '
```

```text
permitrootlogin no
passwordauthentication no
allowusers opsadmin
allowusers student
allowusers astrona
```

A test login with `PreferredAuthentications=none` makes the running daemon refuse the login and list the methods it offers. The journal of the `ssh` service shows why the daemon refused an account:

```sh
ssh -o BatchMode=yes -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null olduser@127.0.0.1 true
sudo journalctl --unit=ssh.service --since=-1min --no-pager --grep=AllowUsers
```

```text
Warning: Permanently added '127.0.0.1' (ED25519) to the list of known hosts.
olduser@127.0.0.1: Permission denied (publickey).
Nov 18 09:09:09 astro-ats-033-playground-010-02 sshd[2961]: User olduser from 127.0.0.1 not allowed because not listed in AllowUsers
```

The daemon offers only `publickey`, and it refused `olduser` because the account is not on the list. The time and the process number in the journal line differ on your run.

## Close the unused account

`olduser` still has a login shell, a password and an SSH key. Give it the shell `/usr/sbin/nologin`, lock its password, and remove its key. Do not delete the account, because its files would then keep a user identifier without an owner name:

```sh
sudo usermod --shell /usr/sbin/nologin --lock olduser
sudo rm /home/olduser/.ssh/authorized_keys
getent passwd olduser
sudo passwd -S olduser
```

```text
olduser:x:1004:1004::/home/olduser:/usr/sbin/nologin
olduser L 2026-11-18 0 99999 7 -1
```

The shell is now `nologin`, and the status letter `L` means the password is locked. The date shows when the password last changed, so it differs on your run.

## Verify the node

None of these changes may affect Kubernetes. Check the node services and the API server:

```sh
systemctl is-active kubelet.service containerd.service ssh.service
kubectl get --raw=/readyz; echo
```

```text
active
active
active
ok
```

## Common pitfalls

> [!WARNING]
> - **Editing the main file only.** A drop-in value that is read first wins. Check the result with `sshd -T`.
> - **Appending `AllowUsers` to the end of the main file.** The line becomes part of the `Match User backup` block and applies to `backup` only.
> - **Leaving out the platform accounts.** `AllowUsers opsadmin` alone blocks new logins as `student` and `astrona`.
> - **Forgetting the reload.** The running daemon keeps its old settings until `systemctl reload ssh.service`.
