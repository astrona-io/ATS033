# Harden Node Access With SSH And Host Login Paths

A Kubernetes node is a Linux host. Every way to log in to it leads to the same place: a shell on the machine that runs every pod of that node. Most of these login paths are not needed. Administrators use one of them, and the others stay open because nobody closed them.

Secure Shell (SSH) is the protocol administrators use to log in to a node over the network. A weak SSH setting, an account that nobody uses any more, or a service account with a login shell each give an attacker a way in. The access controls of the cluster never see these logins, because they happen on the host and not through the Kubernetes API.

Keep one sentence in mind for this module: **a node should accept logins from named administrators with keys only, and every other account and login path should be closed.**

## What you will learn

After this module, you can:

- explain which file and which line decide the value of an SSH setting when several files set it;
- turn off root login and password login, and keep key login working;
- limit SSH logins to named accounts with `AllowUsers`, and explain why a `Match` block can change the meaning of a line;
- change the daemon safely: check the syntax, reload instead of restart, and test from a second session;
- list the accounts that have a login shell, find extra accounts with user identifier 0, and close the login paths of an unused account without deleting it.

## How the module is laid out

You start with **Read The sshd Settings That Decide Who Gets In**. It explains the SSH daemon `sshd`, the order in which it reads its files, and the settings `PermitRootLogin`, `PasswordAuthentication` and `PubkeyAuthentication`. **Limit Who Can Log In** then covers `AllowUsers`, the order of the allow and deny rules, and how to change the daemon without locking yourself out. **Login Shells And Unused Accounts** closes the module. It reads `/etc/passwd`, uses `nologin` shells and locked passwords, and finds accounts that should not exist.

A lab follows the second and the third part, so you can practise those skills right away.

## Before you start

You need basic Linux skills: files, users, `grep`, and running commands as root. You also need the Kubernetes basics: nodes, namespaces, `kubectl get` and `kubectl apply`. You do not need any earlier module.

## Your playground

Your playground is one Ubuntu 24.04 virtual machine (VM). kubeadm installed Kubernetes v1.35.10 on it as a single node, so the same machine runs the control plane, the kubelet and the workloads. You open a shell on it with `astrona ssh astro-ats-033-playground-010-02`. You work as the `student` user, which has a kubeconfig file for the cluster and may run commands as root with `sudo`. Every host-level command in this module changes this VM only, not your own computer.

The playground already contains these objects and settings:

| Where | Object | What it is |
| --- | --- | --- |
| `starfleet` namespace | `probe` Deployment, two pods, label `app: probe` | A small web server that listens on port 8080 |
| `starfleet` namespace | `probe-code` ConfigMap | The Python code of the `probe` web server |
| `starfleet` namespace | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` namespace | `shuttle` pod, label `app: shuttle` | A client pod |
| `outpost` namespace | `drifter` pod, label `app: drifter` | A client pod in another namespace |
| The node | `/etc/ssh/sshd_config` | The main file of the running SSH daemon, with `PermitRootLogin yes`, `PasswordAuthentication no` and a `Match User backup` block added at the end |
| The node | `/etc/ssh/sshd_config.d/50-cloud-init.conf` | A drop-in file with `PasswordAuthentication yes` |
| The node | `opsadmin` account | The administrator account, with a password and the shell `/bin/bash` |
| The node | `olduser` account | An account that nobody uses, with a password, the shell `/bin/bash` and an SSH public key |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
