---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Least Privilege For Host Identities And Administration

Host administration uses Linux identities and authorization mechanisms that are distinct from Kubernetes ServiceAccounts and RBAC. An operator may have narrow Kubernetes permissions but broad SSH or runtime access on a node. Least privilege must therefore be assessed at the host boundary as well as the API boundary.

## Define The Required Task

A monitoring process might need to read selected system statistics. A log collector might need to read approved logs and send them to a protected destination. A maintenance operator might need a narrow administrative operation during an approved change. None of those responsibilities automatically requires unrestricted interactive root access.

Identify which files, sockets, processes and privileged actions the task needs. Linux owner, group and mode permissions determine many file access decisions, while access-control lists can provide additional grants. The effective authority includes all applicable groups and grants. A permission review that considers only the file owner can miss access through another group or an ACL.

## Examine Indirect Elevation

A non-root account can still hold administrator-equivalent authority. Membership in a group that controls a container runtime may allow creation of privileged containers or host mounts. Permission to edit a service definition executed by root can change what code runs with root authority. Access to administrative private keys can provide another route even when the account cannot directly modify protected system files.

Privilege-elevation tools such as sudo delegate operations under a target identity. A narrow rule must account for the behavior of the allowed executable. Some tools can invoke shells, load plugins or write arbitrary files, so permission to run one apparently harmless command may be much broader than its name suggests. Evaluate what the operation enables rather than assuming an allowlist entry is automatically safe.

## Separate Routine And Exceptional Access

Routine agents should use dedicated identities with the permissions their functions require. Shared administrator accounts make actions difficult to attribute and can spread credentials widely. Human operators need individually attributable access, justified elevation and a protected authentication path. Exceptional recovery access can remain available under a defined procedure without becoming every process's default identity.

Suppose a support identity needs to inspect kubelet logs. A design that grants unrestricted runtime control merely to read those logs expands the task unnecessarily. Prefer an approved read path and narrowly scoped file or service permissions. Review whether the selected logs contain credentials or sensitive application information before granting broad access to all diagnostic data.

## Align Credentials And Revocation

A revoked host identity can retain authority through an unremoved SSH key, a copied credential, an active session or another group membership. Access changes should account for those routes. Removing a Kubernetes binding does not necessarily remove a Linux account or stop a host session. Likewise, deleting a local account entry does not automatically revoke credentials issued to an external system.

Credential lifetime, protected storage and rotation reduce the duration and spread of authority. Record who owns service credentials and how replacement nodes obtain them. Avoid placing shared administrative keys in ordinary workload images or broadly accessible bootstrap files.

## Verify The Effective Boundary

The desired outcome is a working task with bounded authority. Review the actual identities used by running processes, durable permission definitions and audit evidence for privileged operations. Ensure that recovery access is documented and controlled so an outage does not invite an untracked blanket privilege grant. Least privilege is a maintained relationship between responsibility and authority, not merely the absence of the username root.

## Common pitfalls

> [!WARNING]
> A non-root identity can still control privileged execution through groups, sockets or writable service configuration. Kubernetes RBAC does not automatically constrain host access.
