---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

This lab runs a virtual machine (VM) with a one-node Kubernetes cluster, and the VM is the node. The account `departed-user` on the node belongs to a person who has left the team. The account still has a working password, its account never expires and its login shell is `/bin/bash`. The team wants to keep the account and its home directory for an audit, so you must disable it, not delete it. The account `pilot` is still in use and must keep working.

During a migration, someone also opened the SSH server: it now accepts logins as `root` and logins with a password. The migration is over, and both must be closed again.

Open a shell on the lab VM and confirm the cluster:

```sh
astrona ssh astro-ats-033-lab-020-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-020-01-02`. You are logged in as the `student` user. Accounts and the SSH server configuration belong to `root`, so run the commands that change them with `sudo`. They change only the lab VM, not your own computer.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Lock the password of `departed-user`, so that `passwd -S departed-user` reports the status `L`.
2. Set the account expiry date of `departed-user` to a date in the past, so that the account can no longer start a session.
3. Change the login shell of `departed-user` to `/usr/sbin/nologin`.
4. Change the SSH daemon (sshd) configuration so that `sshd -T` shows `permitrootlogin no` and `passwordauthentication no`, and make the running SSH service use it.

## Constraints

- Do not delete `departed-user` or its home directory `/home/departed-user`.
- Do not change the account `pilot`: it keeps its password, its shell `/bin/bash` and no expiry date.
- Keep the SSH service running and keep key-based logins working. The configuration must pass `sshd -t`.

## How the answer is checked

The grader runs four checks on the node. The first check reads the status field of `passwd -S departed-user` and expects `L`. The second check reads the expiry field of `/etc/shadow`, expects a day before today, and confirms that `su` to `departed-user` fails. The third check reads the login shell of `departed-user` and accepts `/usr/sbin/nologin`, `/sbin/nologin` or `/bin/false`. The fourth check runs `sshd -t` and `sshd -T`, then makes a login attempt to `127.0.0.1` without a key and expects the running server to offer no `password` method. Every check also confirms that `departed-user` and its home directory still exist and that `pilot` is unchanged.
