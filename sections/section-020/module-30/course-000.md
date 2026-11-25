# Restrict ServiceAccounts And API Tokens

Every pod runs as a ServiceAccount. A ServiceAccount is the Kubernetes object that gives a workload an identity when it talks to the Kubernetes API. By default, Kubernetes also puts a token for that ServiceAccount inside the pod, and the pod can use the token to call the API.

This is a risk when an attacker controls the pod. The attacker then holds the token and gets every permission of the ServiceAccount. Most pods never call the API, so for them the token brings risk and no benefit.

The Certified Kubernetes Security Specialist (CKS) exam expects you to fix this. You give each workload its own identity, you remove tokens that are not needed, and you prefer short-lived tokens over long-lived ones.

Keep one sentence in mind for this module: **give each workload its own ServiceAccount, mount a token only when the workload calls the API, and use short-lived tokens bound to the pod.**

## What you will learn

After this module, you can:

- create a dedicated ServiceAccount for a workload and assign it to a pod;
- turn off the automatic token mount on a ServiceAccount and on a pod, and explain which setting wins;
- describe a bound, projected ServiceAccount token and set its lifetime;
- request a short-lived token with `kubectl create token`;
- remove permissions and the token mount from the `default` ServiceAccount;
- find and delete long-lived ServiceAccount token Secrets.

## How the module is laid out

You start with **Dedicated ServiceAccounts And automountServiceAccountToken**. It shows how a pod gets its identity and its token, and how to turn the token off. **Bound Projected Tokens** then explains how the kubelet gets short-lived tokens for a pod, and how you request one yourself. **The Default ServiceAccount And Unused Tokens** closes the module. It takes the permissions and the token away from the `default` ServiceAccount and finds long-lived token Secrets.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: namespaces, Deployments, pods and `kubectl apply`. You should also know what a Role and a RoleBinding are. You do not need any earlier module.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes v1.35 with one control-plane node and one worker node. You work with `kubectl` only. The cluster already holds these objects:

| Where | Object | What it is |
| --- | --- | --- |
| `starfleet` namespace | `probe` Deployment, two pods, label `app: probe` | A small Python web server that listens on port 8080, with its code in the `probe-code` ConfigMap |
| `starfleet` namespace | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` namespace | `shuttle` pod, label `app: shuttle` | A `busybox` client pod |
| `starfleet` namespace | `monitor` Deployment, one pod, label `app: monitor` | A `busybox` pod that names no ServiceAccount, so it runs as `default` and holds a token |
| `starfleet` namespace | `pod-lister` Role and `default-pod-lister` RoleBinding | The Role allows `get` and `list` on pods, and the RoleBinding gives it to the `default` ServiceAccount |
| `starfleet` namespace | `legacy-monitor` ServiceAccount and `legacy-monitor-token` Secret | A ServiceAccount with a long-lived token Secret of type `kubernetes.io/service-account-token` |
| `outpost` namespace | `drifter` pod, label `app: drifter` | A `busybox` client pod, in another namespace |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
