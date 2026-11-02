---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Summary

Least privilege means that each identity receives the smallest permission that completes its task, for as long as it needs it. On a Linux host, the kernel compares the user, the groups and the file mode, and applies exactly one set of permission bits. A dedicated group gives an account read access to one file without making the file public and without giving the account root. `usermod --append --groups` adds a group without removing the others, and tests must run as the account, because `root` can read everything.

Administrative actions go through `sudo`, whose rules should name exact commands for exact accounts. A rule for all commands, a wildcard argument or a command that opens a shell gives full root. An account is turned off with a password lock, an expiry date and a `nologin` shell together, because a password lock alone does not stop key-based SSH logins. SSH hardening sets `PermitRootLogin no`, turns off password authentication and limits the allowed accounts.

In Kubernetes, a pod acts as a ServiceAccount, and RBAC decides what that ServiceAccount may do. A Role lists verbs on resources inside one namespace, and a RoleBinding gives the Role to subjects. RBAC has no deny rule. `kubectl auth can-i` with `--as` checks the permissions of an identity from the outside. Pods that do not call the API should not receive a token, which `automountServiceAccountToken: false` controls.

Access must be revocable and visible. Revocation removes each layer: group membership, sudoers rules, keys, the account and the Kubernetes bindings. Records of use come from the authentication log, the journal, `auditd` and the Kubernetes API server audit log, which needs an audit policy to exist.

Key facts:

- Linux applies the owner bits, or the group bits, or the other bits, never a mix.
- `usermod --groups` without `--append` replaces all supplementary groups.
- RBAC only adds permissions; deleting the binding removes the access.
- The `default` ServiceAccount should have no bindings.
- A secret value must not reach the audit log; use the `Metadata` level for Secrets.

<!-- astrona:playground:destroy -->
