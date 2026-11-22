---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Restrict SSH Logins In sshd_config

Allow about 10 minutes for the tasks.

Solve this question on: `terminal`

The SSH server (`sshd`) of a Kubernetes node reads the main file `/etc/ssh/sshd_config` and the drop-in files in `/etc/ssh/sshd_config.d/`. The main file looks safe, but two drop-in files loosen it: they allow root logins and password logins. Administrators log in as `opsadmin`. The platform also logs in to the node as `student` and `astrona`, so those two accounts must keep SSH access.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-02-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-02-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Refuse root logins: the effective `PermitRootLogin` value must be `no`.
2. Refuse password logins: the effective `PasswordAuthentication` value must be `no`, and `PubkeyAuthentication` must stay `yes`.
3. Allow only the accounts `opsadmin`, `student` and `astrona` to log in, with `AllowUsers` that applies to every connection, not only to the connections of a `Match` block.
4. Make the running SSH server use the new settings without a reboot.

## Constraints

- Keep the `Include` line, the `Match User backup` block and the `opsadmin` account with the shell `/bin/bash`.
- Check the configuration with `sshd -t` before you reload the server. A broken file can stop new logins.
- The `kubelet`, `containerd` and `ssh` services must stay active, and the API server readiness endpoint `/readyz` must answer `ok`.

## How the answer is checked

The grader runs `sudo sshd -T`, which reads the configuration files the way `sshd` does and prints the effective global settings. Settings inside a `Match` block are not in this output. The first check needs `permitrootlogin no`. The second check needs `passwordauthentication no` and `pubkeyauthentication yes`, and a test login to `opsadmin@127.0.0.1` must show that the running server no longer offers the `password` method. The third check needs `allowusers` lines for exactly `opsadmin`, `student` and `astrona`, and a test login as `ubuntu` must make the running server log `not listed in AllowUsers`. Every check also confirms that `opsadmin` keeps `/bin/bash`, that the `Match User backup` block is still there, that `kubelet`, `containerd` and `ssh` are active and that `/readyz` answers `ok`.
