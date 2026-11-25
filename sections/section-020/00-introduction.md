# Use Least-Privilege Identity And Access Management

Picture an automation account that only needs to restart one service. To make it work quickly, someone gave it full `sudo` rights on the node. The account now can do far more than its job, and anyone who steals its key can too.

Least privilege means that every identity gets only the access its job needs, and nothing more. On a Kubernetes node, there are two kinds of identity. Linux users and groups decide who may read files and run commands on the host. Kubernetes users, groups and ServiceAccounts decide who may call the API server. In this section, you learn how to narrow both kinds, and how to take access away again when it is no longer needed.

## What you will learn

The section moves from the host to the cluster:

- **Apply Least Privilege To Identities.** Linux users, groups and file permissions, `sudo` and account locking, Kubernetes identities and RBAC, removing access on the host and in the cluster, and audit trails that record privileged actions.
- **Least-Privilege RBAC Roles And Bindings.** Roles, ClusterRoles and their bindings, the risk of wildcards, `cluster-admin` and escalation, and checking access with `kubectl auth can-i`.
- **Restrict ServiceAccounts And API Tokens.** Dedicated ServiceAccounts, turning off token automount, short-lived projected tokens, and cleaning up the default ServiceAccount and unused tokens.

## How this section works

Each module has its own playground. The first module works on the node as well as the cluster, so its playground is a virtual machine (VM) that runs Ubuntu and a one-node Kubernetes cluster built with kubeadm. You log in to it with `astrona ssh`. The other two modules work only with the API server, so their playground is a private `kind` cluster. Start the playground from the first page of the module and keep it running while you read.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh environment and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- explain the difference between Linux users and groups and Kubernetes identities;
- set file and socket permissions, and limit `sudo` to the commands a user needs;
- lock accounts and remove access on the host and in the cluster;
- record privileged actions on the node and in the cluster, and keep audit rules after a reboot;
- write narrow Roles and bindings, and remove wildcards and needless `cluster-admin` grants;
- give each workload its own ServiceAccount, turn off token automount, and use short-lived projected tokens.
