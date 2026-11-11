---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Harden Node Access With SSH And Host Login Paths

A Kubernetes node is a Linux host, and every way to log in to it is a path to the same place: a shell on the machine that runs every pod of the node. Most of these paths are not needed. Administrators use one of them, and the others stay open because nobody closed them. A weak Secure Shell (SSH) setting, an account that nobody uses any more, or a service account with a login shell each give an attacker a way in that the cluster's own access controls never see.

Keep one sentence in mind for this module: **a node should accept logins from named administrators with keys only, and every other account and login path should be closed.** You will read the settings of the SSH daemon and find the value that really applies, limit which accounts may log in, and close the login paths of accounts that do not need one.

The module has three parts. **Read The sshd Settings That Decide Who Gets In** explains the SSH daemon `sshd`, the order in which it reads its files, and the settings `PermitRootLogin`, `PasswordAuthentication` and `PubkeyAuthentication`. **Limit Who Can Log In** covers `AllowUsers`, the order of the allow and deny rules, and how to change the daemon without locking yourself out. **Login Shells And Unused Accounts** reads `/etc/passwd`, uses `nologin` shells and locked passwords, and finds accounts that should not exist.

## Learning objectives

After this module you can:

- Explain which file and which line decide the value of an SSH setting when several files set it.
- Turn off root login and password login and keep key login working.
- Limit SSH logins to named accounts with `AllowUsers`, and explain why a `Match` block can change the meaning of a line.
- Change the daemon safely: check the syntax, reload instead of restart, and test from a second session.
- List accounts that have a login shell, find extra accounts with user identifier 0, and close the login paths of an unused account without deleting it.

## Before you start

You need basic Linux skills (files, users, `grep`, running commands as root) and Kubernetes basics (nodes, namespaces, `kubectl get` and `kubectl apply`). You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container that runs systemd, so a node behaves like a small Linux host. You reach a node with `podman exec`, which runs one command inside the node container as root. Every host-level command in this module names the node containers of this playground only.

| Where | What is in it |
| --- | --- |
| `starfleet` namespace | The `probe` Deployment with two replicas, the `probe` Service and the `shuttle` client pod |
| `outpost` namespace | The `drifter` client pod |
| Control-plane node | A stand-in SSH server configuration in `/etc/ssh/sshd_config` and in the drop-in file `/etc/ssh/sshd_config.d/50-cloud-init.conf`, and the accounts `opsadmin` and `olduser` |

The setup script writes the SSH files itself, so the exercises read and change real files with the real syntax without depending on an SSH server in the node image.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Independent live assessment

Prepare with [Verify SSH Authentication After A Reload](course-03a-test-live-ssh-authentication.md). [Harden A Running SSH Service](labs/lab-01/question.md) uses its own qemu environment. The running SSH service rejects a fresh root key login; The running SSH service rejects a fresh password login and permits the administrator key; Only opsadmin can log in and olduser has a locked password and nologin shell.
