---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Apply Least Privilege To Identities

An account that can do more than its job needs turns a small mistake or a stolen password into a large incident. A deployment account that can restart one service but also has unrestricted root access can read every secret on the node and change every file. Least privilege means that each identity, human or automated, receives exactly the permissions its task needs and nothing more, for as long as it needs them.

Keep one sentence in mind for this module: **grant each identity the smallest permission that completes its task, and be able to take it back and to see when it was used.** You will give a Linux account read access to one file through a group, review how `sudo` and account locks limit administrative access, grant a Kubernetes ServiceAccount a narrow Role, and then revoke and audit access.

The module has four parts. **Users, Groups And File Permissions** shows how Linux decides whether an account may read a file, and how a group grants one report without granting root. **Privilege Elevation And Account Locking** covers `sudo`, `sudoers`, locked accounts and SSH login settings. **Kubernetes Identities And RBAC** creates a ServiceAccount with a Role that allows one verb on one resource and checks it with `kubectl auth can-i`. **Revocation And Audit** removes group membership and a RoleBinding, checks that access is gone, and shows where actions are recorded.

## Learning objectives

After this module you can:

- Explain how Linux compares the user, the groups and the file mode to decide on access.
- Grant read access to one file through a group, without adding the account to the root group.
- Describe what a `sudoers` rule allows and why an unrestricted rule is dangerous.
- Create a ServiceAccount, a Role and a RoleBinding, and verify them with `kubectl auth can-i`.
- Revoke host and Kubernetes access and confirm that it no longer works.

## Before you start

You need basic Linux skills (files, owners, modes) and Kubernetes basics (namespaces, pods, `kubectl apply`). You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. `kind` runs each node as a Podman container with systemd, and you run one command inside a node with `podman exec`. Every host-level command names the node containers of this playground only.

| Where | What is in it |
| --- | --- |
| Control-plane node, accounts | The user `training-reader` (UID is not zero, shell `/bin/sh`) and the group `training-readers`. The user is not yet a member of the group |
| Control-plane node, files | `/var/lib/training-identity/public-report` (owner `root`, group `training-readers`, mode `0640`) and `/var/lib/training-identity/private-report` (owner `root`, group `root`, mode `0600`) |
| `starfleet` namespace | The `probe` Deployment, the `probe` Service and the `shuttle` client pod |
| `outpost` namespace | The `drifter` client pod |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
