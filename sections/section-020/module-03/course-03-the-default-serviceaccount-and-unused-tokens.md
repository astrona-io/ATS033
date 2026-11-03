---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# The Default ServiceAccount And Unused Tokens

Two kinds of leftover identity cause most token problems. The first is the `default` ServiceAccount, which exists in every namespace and which every pod without a `serviceAccountName` uses. The second is the long-lived token Secret that an older cluster, a script or an operator created for a ServiceAccount and nobody deleted. This part closes the first and removes the second.

## The default ServiceAccount

Kubernetes creates a ServiceAccount called `default` in every namespace and recreates it if you delete it. You cannot remove it, so you must make it harmless. Two actions do that. Remove every RoleBinding and ClusterRoleBinding that names it as a subject, because those permissions reach every pod that does not name its own ServiceAccount. Set `automountServiceAccountToken: false` on it, so that pods using it receive no token unless a pod asks for one.

Select the playground first:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-03" || exit 1
```

In the playground, someone bound a Role to `default` in `starfleet`. Show what the ServiceAccount can do, and which bindings name it:

```sh
kubectl auth can-i list pods --as=system:serviceaccount:starfleet:default -n starfleet
kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns=KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,SUBJECTS:.subjects[*].name | grep -w default
```

The first answer is `yes`, and the second command lists the RoleBinding `default-pod-lister`. Every pod in `starfleet` that names no ServiceAccount, including a pod created by an attacker, can now list pods. Delete the binding. The Role it referenced stays behind and is harmless without a binding, but you can delete it too:

```sh
kubectl -n starfleet delete rolebinding default-pod-lister
kubectl auth can-i list pods --as=system:serviceaccount:starfleet:default -n starfleet
```

The answer is now `no`. Next, turn off the token mount for the account. Save this as `serviceaccount-default.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: starfleet
automountServiceAccountToken: false
```

Apply it:

```sh
kubectl apply -f serviceaccount-default.yaml
```

New pods that use `default` now start without a token, and a pod that needs one must set `automountServiceAccountToken: true` itself, which makes the need visible in review. Running pods keep the token they have until they restart. Repeat both actions in every namespace you own. The same applies to namespaces that you create later, so many teams add the step to their namespace templates.

## Long-lived token Secrets

A Secret of type `kubernetes.io/service-account-token` holds a token that has no expiry. The control plane filled such Secrets for every ServiceAccount before version 1.24. Today the control plane fills one only when someone creates it by hand with the annotation `kubernetes.io/service-account.name`, but old clusters that were upgraded often still hold the old ones. The token stays valid until the Secret or the ServiceAccount is deleted. Anyone who can read the Secret, for example through the `get` verb on `secrets`, can use it from anywhere.

List the token Secrets with a field selector on the Secret type:

```sh
kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/service-account-token
```

The output contains `legacy-monitor-token` in `starfleet`. Decide for each entry whether any system still uses it. If a script or a CI job needs a credential, replace the Secret with `kubectl create token` or with a projected token. If nothing uses it, delete it. The token stops working immediately:

```sh
kubectl -n starfleet delete secret legacy-monitor-token
kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/service-account-token
```

The second command no longer lists the Secret. Check also that the ServiceAccount itself is still needed: a ServiceAccount that no pod uses and no binding names can be deleted, because deleting it also invalidates every token that was issued for it.

## A short review checklist

For each namespace, ask five questions. Does each workload use its own ServiceAccount? Does every pod that never calls the API run with `automountServiceAccountToken: false`? Does the `default` ServiceAccount have no bindings and no mount? Do all remaining tokens expire? Are there ServiceAccounts that nobody uses? Together, these questions turn a pile of identities into a list you can reason about.

You now can close the `default` ServiceAccount and remove tokens that never expire. Combined with narrow RBAC rules, each workload holds one identity, a short-lived token and only the permissions it needs.

## Common pitfalls

> [!WARNING]
> - **Deleting the `default` ServiceAccount.** The controller recreates it with its defaults, so the change does nothing.
> - **Deleting a token Secret that a system still uses.** That system loses access immediately. Find the user first.
> - **Fixing one namespace.** Every namespace has its own `default` ServiceAccount.
> - **Expecting running pods to lose their token.** Pods keep the token until they restart.
