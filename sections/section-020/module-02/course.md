---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Least-Privilege RBAC Roles And Bindings

Role-based access control (RBAC) decides what every user and every ServiceAccount may do through the Kubernetes API. A single over-broad binding can turn one stolen token into control of the whole cluster. The Certified Kubernetes Security Specialist (CKS) exam expects you to read RBAC objects, find the ones that grant too much, and replace them with the smallest set of permissions that still lets the workload do its job.

Keep one sentence in mind for this module: **write the narrowest Role that completes the task, bind it in the smallest scope, and prove the result with `kubectl auth can-i`.** You will compare Roles and ClusterRoles, bind them in one namespace or in the whole cluster, remove wildcards and `cluster-admin` bindings, and audit what already exists.

The module has three parts. **Roles, ClusterRoles And Bindings** shows what each of the four RBAC kinds does and how the scope of a binding limits a ClusterRole. **Wildcards, cluster-admin And Escalation** shows how permissions grow too wide and how the API server stops a user from granting more than they hold. **Audit Permissions With kubectl auth can-i** tests identities from the outside, explains aggregated ClusterRoles and finds over-broad bindings.

## Learning objectives

After this module you can:

- Explain the difference between a Role and a ClusterRole, and between a RoleBinding and a ClusterRoleBinding.
- Limit a ClusterRole to one namespace by binding it with a RoleBinding.
- Write rules with exact API groups, resources, subresources and verbs, and avoid wildcards.
- Explain why `cluster-admin` bindings are dangerous and how privilege escalation prevention works.
- Use `kubectl auth can-i`, including `--as` and `--list`, to test an identity.
- Find over-broad bindings in a cluster.

## Before you start

You need Kubernetes basics: namespaces, pods, ServiceAccounts and `kubectl apply`. You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. You work with `kubectl` only. The cluster already holds these objects:

| Where | What is in it |
| --- | --- |
| `starfleet` namespace | The `probe` Deployment, the `probe` Service and the `shuttle` client pod |
| `outpost` namespace | The `drifter` client pod |
| `starfleet` namespace, identity | The `ops-agent` ServiceAccount, a Role `ops-wide` that allows every verb on every resource, and a RoleBinding that gives it to `ops-agent` |
| Cluster-wide | A ClusterRoleBinding `ops-agent-admin` that binds `ops-agent` to the ClusterRole `cluster-admin` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
