# Least-Privilege RBAC Roles And Bindings

Every request to the Kubernetes API, from a user or from a workload, must pass an authorization check before the API server runs it. Role-based access control (RBAC) is the system that makes this check. It decides what every user and every ServiceAccount may do. A single binding that grants too much can turn one stolen token into control of the whole cluster.

The Certified Kubernetes Security Specialist (CKS) exam expects you to read RBAC objects and find the ones that grant too much. You must then replace them with the smallest set of permissions that still lets the workload do its job. This is called least privilege.

Keep one sentence in mind for this module: **write the narrowest Role that completes the task, bind it in the smallest scope, and prove the result with `kubectl auth can-i`.** You will compare Roles and ClusterRoles, bind them in one namespace or in the whole cluster, remove wildcards and `cluster-admin` bindings, and audit what already exists.

## What you will learn

After this module, you can:

- explain the difference between a Role and a ClusterRole, and between a RoleBinding and a ClusterRoleBinding;
- limit a ClusterRole to one namespace by binding it with a RoleBinding;
- write rules with exact API groups, resources, subresources and verbs, and avoid wildcards;
- explain why `cluster-admin` bindings are dangerous and how privilege escalation prevention works;
- use `kubectl auth can-i`, including `--as` and `--list`, to test an identity;
- find over-broad bindings in a cluster.

## How the module is laid out

You start with **Roles, ClusterRoles And Bindings**, which shows what each of the four RBAC kinds does and how the scope of a binding limits a ClusterRole. **Wildcards, cluster-admin And Escalation** then shows how permissions grow too wide, and how the API server stops a user from granting more than they hold. **Audit Permissions With kubectl auth can-i** closes the module. It tests identities from the outside, explains aggregated ClusterRoles and finds over-broad bindings.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: namespaces, pods, ServiceAccounts and `kubectl apply`. You do not need any earlier module.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes 1.35, with one control-plane node and one worker node. You work with `kubectl` only. The cluster already holds these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe-code` ConfigMap | Holds `server.py`, the code of the small web server |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small web server that listens on port 8080 |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod in another namespace |
| `starfleet` | `ops-agent` ServiceAccount | An identity for a workload, with no token mounted into pods |
| `starfleet` | `ops-wide` Role | Allows every verb on every resource in every API group |
| `starfleet` | `ops-wide` RoleBinding | Gives the `ops-wide` Role to `ops-agent` |
| cluster-wide | `ops-agent-admin` ClusterRoleBinding | Binds `ops-agent` to the ClusterRole `cluster-admin` |

The `ops-agent` identity is bound far too widely on purpose. You will measure its access and then fix it.

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
