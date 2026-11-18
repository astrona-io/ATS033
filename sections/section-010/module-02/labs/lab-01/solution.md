---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Restrict SSH Logins In sshd_config Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-02-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-02-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

Keep this first shell open until the end. If a change locks out new logins, you can still repair it from this shell.

## Read the files and the effective settings

The SSH server, `sshd`, reads `/etc/ssh/sshd_config` from the top. `grep -v` with the pattern `^(#|$)` hides comment lines and empty lines, and `-n` prints the line numbers:

```sh
grep -n -v -E '^(#|$)' /etc/ssh/sshd_config
```

```text
12:Include /etc/ssh/sshd_config.d/*.conf
71:KbdInteractiveAuthentication no
94:UsePAM yes
99:X11Forwarding yes
103:PrintMotd no
121:AcceptEnv LANG LC_*
124:Subsystem	sftp	/usr/lib/openssh/sftp-server
133:Match User backup
134:    # The backup account may only copy files.
135:    ForceCommand internal-sftp
136:    AllowTcpForwarding no
```

The `Include` line on line 12 reads every file in `/etc/ssh/sshd_config.d/` that ends in `.conf`, in alphabetical order, at that position. So `sshd` reads the drop-in files before the rest of the main file. For most keywords, the first value that `sshd` reads wins. Every line after `Match User backup` belongs to that block, up to the end of the file. List the drop-in files and read them. One of them has the mode `600`, so only root can read it:

```sh
ls -l /etc/ssh/sshd_config.d/
sudo grep -H . /etc/ssh/sshd_config.d/10-legacy-root.conf /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
```

```text
total 12
-rw-r--r-- 1 root root 84 Nov 18 08:58 10-legacy-root.conf
-rw------- 1 root root 27 Nov 18 08:58 50-cloud-init.conf
-rw-r--r-- 1 root root 26 Aug  1 13:01 60-cloudimg-settings.conf
/etc/ssh/sshd_config.d/10-legacy-root.conf:# Added during the first install so that root could copy files.
/etc/ssh/sshd_config.d/10-legacy-root.conf:permitrootlogin yes
/etc/ssh/sshd_config.d/50-cloud-init.conf:PasswordAuthentication yes
/etc/ssh/sshd_config.d/60-cloudimg-settings.conf:PasswordAuthentication no
```

`50-cloud-init.conf` sorts before `60-cloudimg-settings.conf`, so `PasswordAuthentication yes` wins over the later `no`. Keywords do not depend on case, so `permitrootlogin yes` in lower case counts too. Reading files by hand is easy to get wrong. `sshd -T` (test mode, extended) makes `sshd` read all the files itself and print the effective global value of every keyword, in lower case:

```sh
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers) '
```

```text
permitrootlogin yes
pubkeyauthentication yes
passwordauthentication yes
```

Root and password logins are allowed, and there is no `allowusers` line, so every account may log in. The files are not the whole story: the running server uses the settings it read when it last started or reloaded. A test login with `PreferredAuthentications=none` makes the server answer with the methods it offers. `BatchMode=yes` stops the client from asking for a password:

```sh
ssh -o BatchMode=yes -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null opsadmin@127.0.0.1 true
```

```text
Warning: Permanently added '127.0.0.1' (ED25519) to the list of known hosts.
opsadmin@127.0.0.1: Permission denied (publickey,password).
```

The server offers `publickey` and `password`.

## Fix the values that sshd reads first

Change the lines that win, which are the lines in the drop-in files. The `I` flag at the end of the first `sed` expression makes the pattern ignore case, so it matches `permitrootlogin`:

```sh
sudo sed -i 's/^permitrootlogin .*/PermitRootLogin no/I' /etc/ssh/sshd_config.d/10-legacy-root.conf
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
```

The commands print nothing when they succeed. Next, add the `AllowUsers` line in its own drop-in file. The `Include` line sits above the `Match` block, so a line in a drop-in file is global. `AllowUsers` lines add up instead of using the first value, so the file name does not matter for this keyword. The list must contain `student` and `astrona` as well, or the platform loses its SSH access:

```sh
echo "AllowUsers opsadmin student astrona" | sudo tee /etc/ssh/sshd_config.d/10-allow-users.conf
```

```text
AllowUsers opsadmin student astrona
```

## Test and reload the server

`sshd -t` checks the syntax of all the files and prints nothing when they are valid. Only then reload the server. `systemctl reload` makes the running `sshd` read its configuration again without closing open sessions:

```sh
sudo sshd -t
sudo systemctl reload ssh.service
```

Both commands print nothing. Check the effective settings again, globally and for a connection of the `backup` account. The option `-C user=backup` applies the `Match` blocks for that account:

```sh
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers) '
sudo sshd -T -C user=backup | grep -E '^(allowusers|forcecommand) '
```

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
allowusers opsadmin
allowusers student
allowusers astrona
forcecommand internal-sftp
allowusers opsadmin
allowusers student
allowusers astrona
```

`sshd -T` prints one `allowusers` line for each account. The `backup` account still gets `forcecommand internal-sftp` from its `Match` block, and the same `AllowUsers` list applies to it.

## Verify the running server

Repeat the test login for `opsadmin`, then try `ubuntu`, an account with a shell that is not on the list:

```sh
ssh -o BatchMode=yes -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null opsadmin@127.0.0.1 true
ssh -o BatchMode=yes -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@127.0.0.1 true
sudo journalctl --unit=ssh.service --since=-1min --no-pager --grep=AllowUsers
```

```text
Warning: Permanently added '127.0.0.1' (ED25519) to the list of known hosts.
opsadmin@127.0.0.1: Permission denied (publickey).
Warning: Permanently added '127.0.0.1' (ED25519) to the list of known hosts.
ubuntu@127.0.0.1: Permission denied (publickey).
Nov 18 08:58:43 astro-ats-033-lab-010-02-01 sshd[2629]: User ubuntu from 127.0.0.1 not allowed because not listed in AllowUsers
```

The running server now offers only `publickey`. The client sees the same answer for `ubuntu`, because `sshd` does not tell a client why it refuses a login. The journal of the `ssh` service shows the real reason. Finally check the node services:

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

Then submit.

## Common pitfalls

> [!WARNING]
> - **Fixing only the main file.** The drop-in values are read first and win. Check the result with `sshd -T`, not by reading one file.
> - **Appending `AllowUsers` after a `Match` block.** A line added with `>>` to the end of `sshd_config` belongs to `Match User backup`. `sshd -T` then shows no global `allowusers` line.
> - **Locking out the platform accounts.** `AllowUsers opsadmin` alone refuses `student` and `astrona`. New logins fail, and only an open session can repair the file.
> - **Forgetting the reload.** `sshd -T` reads the files, but the running server keeps its old settings until `systemctl reload ssh.service`.
