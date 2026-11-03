---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Restrict ServiceAccounts And API Tokens

Every pod runs as a ServiceAccount, and by default Kubernetes places a token for that ServiceAccount inside the pod. The pod can use the token to call the Kubernetes API. If an attacker controls the pod, the attacker controls the token and receives every permission of the ServiceAccount. Most pods never call the API, so for them the token is risk without benefit. The Certified Kubernetes Security Specialist (CKS) exam expects you to give each workload its own identity, remove tokens that are not needed and prefer short-lived tokens over long-lived ones.

Keep one sentence in mind for this module: **give each workload its own ServiceAccount, mount a token only when the workload calls the API, and use short-lived tokens bound to the pod.** You will create dedicated ServiceAccounts, turn off the token mount, project a bound token with a lifetime, close the `default` ServiceAccount and remove old token Secrets.

The module has three parts. **Dedicated ServiceAccounts And automountServiceAccountToken** shows how a pod gets its identity and how to turn the token off. **Bound Projected Tokens** explains how the kubelet issues short-lived tokens and how to request one yourself. **The Default ServiceAccount And Unused Tokens** closes the `default` ServiceAccount and finds long-lived token Secrets.

## Learning objectives

After this module you can:

- Create a dedicated ServiceAccount for a workload and assign it to a pod.
- Turn off the automatic token mount on a ServiceAccount and on a pod, and explain which setting wins.
- Describe a bound, projected ServiceAccount token and configure its lifetime.
- Request a short-lived token with `kubectl create token`.
- Remove permissions and the token mount from the `default` ServiceAccount.
- Find and delete long-lived ServiceAccount token Secrets.

## Before you start

You need Kubernetes basics: namespaces, Deployments, pods and `kubectl apply`. You also need to know what a Role and a RoleBinding are. You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. You work with `kubectl` only. The cluster already holds these objects:

| Where | What is in it |
| --- | --- |
| `starfleet` namespace | The `probe` Deployment, the `probe` Service and the `shuttle` client pod |
| `outpost` namespace | The `drifter` client pod |
| `starfleet` namespace, identity | The `monitor` Deployment, which runs as the `default` ServiceAccount, and a RoleBinding `default-pod-lister` that lets `default` list pods |
| `starfleet` namespace, tokens | The ServiceAccount `legacy-monitor` and a long-lived token Secret `legacy-monitor-token` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
