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

Your playground is one Ubuntu 24.04 virtual machine (VM). kubeadm installed Kubernetes v1.35.10 on it as a single node, so the same machine runs the control plane, the kubelet and the workloads. You open a shell on it with `astrona ssh astro-ats-033-playground-010-02` and work as the `student` user, which has a kubeconfig file for the cluster and may run commands as root with `sudo`. Every host-level command in this module changes this VM only, not your own computer.

| Where | What is in it |
| --- | --- |
| `starfleet` namespace | The `probe` Deployment with two replicas, the `probe` Service and the `shuttle` client pod |
| `outpost` namespace | The `drifter` client pod |
| The node | A running SSH daemon whose main file `/etc/ssh/sshd_config` and drop-in file `/etc/ssh/sshd_config.d/50-cloud-init.conf` allow root and password logins, a `Match User backup` block, and the accounts `opsadmin` and `olduser` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
