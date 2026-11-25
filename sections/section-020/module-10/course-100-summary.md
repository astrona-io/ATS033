# Summary

Least privilege means that each identity gets the smallest permission that completes its task, and only for as long as it needs it. On a Linux host, the kernel compares the user ID, the groups and the file mode, and then applies exactly one set of permission bits. A dedicated group gives an account read access to one file. The file does not become public, and the account does not get root.

`usermod --append --groups` adds a group and keeps the other groups. Tests must run as the account itself, because `root` can read everything.

Administrator actions go through `sudo`. Its rules should name exact commands for exact accounts. A rule for all commands, a wildcard argument or a command that opens a shell gives full root.

You turn an account off with three settings together: a password lock, an expiry date and a `nologin` shell. A password lock alone does not stop SSH logins with a key. SSH hardening sets `PermitRootLogin no`, turns off password logins and limits the accounts that may log in.

In Kubernetes, a pod acts as a ServiceAccount, and RBAC (role-based access control) decides what that ServiceAccount may do. A Role lists verbs on resources inside one namespace, and a RoleBinding gives the Role to subjects. RBAC has no deny rule. `kubectl auth can-i` with `--as` checks the permissions of an identity from the outside. Pods that do not call the API should not receive a token, and `automountServiceAccountToken: false` turns the token mount off.

Access must be easy to take back and easy to see. To revoke access, you remove each layer: group membership, sudoers rules, SSH keys, the account and the Kubernetes bindings. Records of use come from the authentication log, the systemd journal, `auditd` and the Kubernetes API server audit log. The API server writes that log only when it has an audit policy.

An `auditd` rule added with `auditctl` lasts only until `auditd` restarts or the node reboots. A persistent rule goes in a file that ends in `.rules` under `/etc/audit/rules.d/`. `augenrules` joins those files into `/etc/audit/audit.rules`, and `augenrules --load` puts the rules into the kernel without a reboot.

The kernel records only events that match a rule that is already loaded. So the watch must be active before the change it should record. Later, `ausearch --input-logs` with `-k` and a key, and `-f` with a path, finds the record.

Key facts to remember:

- Linux applies the owner bits, or the group bits, or the other bits, never a mix.
- `usermod --groups` without `--append` replaces all supplementary groups.
- RBAC only adds permissions. Deleting the binding removes the access.
- The `default` ServiceAccount should have no bindings.
- A secret value must not reach the audit log. Use the `Metadata` level for Secrets.
- `augenrules --check` reports whether the rule files differ from the generated `/etc/audit/audit.rules`.

<!-- astrona:playground:destroy -->
