---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Harden RBAC And ServiceAccounts In Two Namespaces

Harden RBAC and ServiceAccounts across two namespaces.

## Starting state

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The `outpost` namespace holds a `deployer` ServiceAccount bound to `cluster-admin`, a `default` ServiceAccount bound to `edit`, a `reporter` Deployment that runs with the `default` ServiceAccount, and a long-lived token Secret.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-capstone-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Make four changes. Keep the `probe` Deployment and the client pods unchanged.

1. The `deployer` ServiceAccount in `outpost` is bound to `cluster-admin` by the ClusterRoleBinding `deployer-admin`. Delete that binding. Create the Role `deployer` in `outpost` and a RoleBinding `deployer` so that the ServiceAccount can `get`, `list`, `patch` and `update` Deployments in `apps`, and `get` and `list` pods, in `outpost` only. It must not be able to delete Deployments, read Secrets, patch Deployments in `starfleet` or list nodes.
2. The `default` ServiceAccount in `outpost` is bound to the ClusterRole `edit` by the RoleBinding `default-edit`. Delete the binding and set `automountServiceAccountToken: false` on the ServiceAccount. It must not be able to create pods.
3. The `reporter` Deployment in `outpost` uses the `default` ServiceAccount and must read pods in `starfleet`. Create the ServiceAccount `reporter` in `outpost` with `automountServiceAccountToken: false`. In `starfleet`, create the Role `pod-reader` (`get` and `list` on pods) and the RoleBinding `reporter-pod-reader` that binds it to the `reporter` ServiceAccount of `outpost`. Change the Deployment to use the ServiceAccount, set `automountServiceAccountToken: false` in the pod template, and project one bound token that expires after 3600 seconds into the file `/var/run/secrets/tokens/api-token`. The ServiceAccount must be able to get and list pods in `starfleet` and must not be able to list pods in `outpost` or get Secrets in `starfleet`.
4. Delete the long-lived token Secret `legacy-deployer-token` in `outpost`.

## Verify The Result

The grader checks the required object fields and the answers of `kubectl auth can-i`. Wait for the rollout to finish before you submit. Preserve the namespaces, workload names and unrelated components.
