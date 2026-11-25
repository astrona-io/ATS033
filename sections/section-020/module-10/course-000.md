# Apply Least Privilege To Identities

An account that can do more than its job needs is a risk. With that account, a small mistake or a stolen password turns into a large incident. Think of a deployment account that must restart one service but also has unrestricted root access: it can read every secret on the node and change every file.

Least privilege is the rule that fixes this. Each identity, human or automated, receives exactly the permissions its task needs, nothing more, and only for as long as it needs them.

Keep one sentence in mind for this module: **grant each identity the smallest permission that completes its task, and be able to take it back and to see when it was used.** You give a Linux account read access to one file through a group. You review how `sudo` and account locks limit administrative access. You grant a Kubernetes ServiceAccount a narrow Role. Then you revoke the access and audit it.

## What you will learn

After this module, you can:

- explain how Linux compares the user, the groups and the file mode to decide on access;
- grant read access to one file through a group, without adding the account to the root group;
- describe what a `sudoers` rule allows and why an unrestricted rule is dangerous;
- create a ServiceAccount, a Role and a RoleBinding, and verify them with `kubectl auth can-i`;
- revoke host and Kubernetes access and confirm that it no longer works;
- make an `auditd` rule persistent, load it without a reboot and find the record of a change with `ausearch`.

## How the module is laid out

You start with **Users, Groups And File Permissions**, which shows how Linux decides whether an account may read a file, and how a group grants one report without granting root. **Privilege Elevation And Account Locking** covers `sudo`, the `sudoers` rules, locked accounts and the SSH login settings. **Kubernetes Identities And RBAC** creates a ServiceAccount with a Role that allows one verb on one resource, and checks it with `kubectl auth can-i`.

**Revoking Host And Kubernetes Access** removes a group membership and a RoleBinding, and checks that the access is gone. **Audit Trails On The Node And In The Cluster** reads the sudo and SSH records, adds an `auditd` watch rule on the sudoers files, and names the settings the API server needs for its audit log. **Persistent Audit Rules With augenrules** closes the module: it writes an audit rule to a file in `/etc/audit/rules.d/`, loads it without a reboot, and finds the record of one new sudoers file.

## Before you start

You need basic Linux skills: files, owners and modes. You also need the Kubernetes basics: namespaces, pods and `kubectl apply`. You do not need anything else from this course first.

## Your playground

Your playground is a virtual machine (VM) that runs Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster built with kubeadm. kubeadm is the tool that sets up the cluster. The VM is the node: it runs the control plane and the workloads. Ubuntu on this VM provides the SSH daemon (`ssh.service`), `sudo` and the audit daemon `auditd`.

You open a shell on the VM with `astrona ssh astro-ats-033-playground-020-01`, and you work as the `student` user. `student` may run any command as `root` through `sudo`. It also has a kubeconfig file with administrator access to the cluster. Every command changes only this VM, not your own computer.

The VM already holds these accounts, files and workloads:

| Where | Object | What it is |
| --- | --- | --- |
| Node | `training-reader` user | An account with a UID that is not zero, the shell `/bin/sh` and a real password. It is not yet a member of `training-readers` |
| Node | `training-readers` group | The group that may read `public-report` |
| Node | `/var/lib/training-identity/public-report` | Owner `root`, group `training-readers`, mode `0640` |
| Node | `/var/lib/training-identity/private-report` | Owner `root`, group `root`, mode `0600` |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small web server that listens on port 8080 |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | The Python code of the `probe` web server |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A `busybox` client pod |
| `outpost` | `drifter` pod, label `app: drifter` | A `busybox` client pod, in another namespace |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
