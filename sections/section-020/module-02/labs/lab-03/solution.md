---
exam_objectives:
- Using least-privilege identity and access management
---
# Find Hidden RBAC Grants Solution

Select the private cluster and put the ServiceAccount's user name in a variable. A ServiceAccount has the user name `system:serviceaccount:<namespace>:<name>`.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-03" || exit 1
dashboard=system:serviceaccount:starfleet-033-020-02-03:dashboard
```

## 1. Confirm both problems

```sh
kubectl auth can-i get secrets --as=auditor -n starfleet-033-020-02-03
kubectl auth can-i create deployments --as=$dashboard -n starfleet-033-020-02-03
kubectl auth can-i list pods --as=system:serviceaccount:starfleet-033-020-02-03:default -n starfleet-033-020-02-03
```

```text
yes
yes
yes
```

All three answers should be `no`. List the RoleBindings of the namespace to see who gets what:

```sh
kubectl -n starfleet-033-020-02-03 get rolebindings -o wide
```

```text
NAME             ROLE               AGE   USERS     GROUPS                                           SERVICEACCOUNTS
auditor-view     ClusterRole/view   39s   auditor                                                    
crew-editors     ClusterRole/edit   39s             system:serviceaccounts:starfleet-033-020-02-03   
dashboard-view   ClusterRole/view   39s                                                              starfleet-033-020-02-03/dashboard
```

The RoleBinding `crew-editors` names no single account. It names the group `system:serviceaccounts:starfleet-033-020-02-03`. The API server puts every ServiceAccount of that namespace in this group, so every one of them gets `edit`, including `default`.

## 2. Find where view gets Secret access

The ClusterRole `view` is an aggregated ClusterRole. Its `aggregationRule` selects other ClusterRoles by label. The aggregation controller in `kube-controller-manager` copies their rules into `view` and keeps them in sync.

```sh
kubectl get clusterrole view -o jsonpath='{.aggregationRule}'
```

```text
{"clusterRoleSelectors":[{"matchLabels":{"rbac.authorization.k8s.io/aggregate-to-view":"true"}}]}
```

List every ClusterRole with that label:

```sh
kubectl get clusterroles -l rbac.authorization.k8s.io/aggregate-to-view=true
```

```text
NAME                        CREATED AT
secret-peek-033-020-02-03   2026-11-17T21:53:57Z
system:aggregate-to-view    2026-11-17T21:53:27Z
```

`system:aggregate-to-view` is a default ClusterRole that Kubernetes creates. The other one was added later. Look at its rules:

```sh
kubectl describe clusterrole secret-peek-033-020-02-03
```

```text
Name:         secret-peek-033-020-02-03
Labels:       rbac.authorization.k8s.io/aggregate-to-view=true
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  secrets    []                 []              [get list watch]
```

This rule reaches every subject bound to `view` in every namespace.

## 3. Remove the aggregated ClusterRole

Delete the ClusterRole. The aggregation controller then rebuilds the rules of `view` without it. Editing `view` directly does not help, because the controller writes the rules back.

```sh
kubectl delete clusterrole secret-peek-033-020-02-03
```

```text
clusterrole.rbac.authorization.k8s.io "secret-peek-033-020-02-03" deleted
```

Then check the result:

```sh
kubectl auth can-i get secrets --as=auditor -n starfleet-033-020-02-03
kubectl auth can-i list configmaps --as=auditor -n starfleet-033-020-02-03
```

```text
no
yes
```

`auditor` lost the Secrets and kept the other reads. If the first answer is still `yes`, wait a few seconds for the controller and run it again.

## 4. Delete the group binding

```sh
kubectl -n starfleet-033-020-02-03 delete rolebinding crew-editors
```

```text
rolebinding.rbac.authorization.k8s.io "crew-editors" deleted from starfleet-033-020-02-03 namespace
```

Then check the result:

```sh
kubectl auth can-i create deployments --as=$dashboard -n starfleet-033-020-02-03
kubectl auth can-i get secrets --as=$dashboard -n starfleet-033-020-02-03
kubectl auth can-i list pods --as=$dashboard -n starfleet-033-020-02-03
kubectl auth can-i list pods --as=system:serviceaccount:starfleet-033-020-02-03:default -n starfleet-033-020-02-03
```

```text
no
no
yes
no
```

`dashboard` keeps its read access through `dashboard-view`, and `default` has no access. Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-02-03`.

## Common pitfalls

> [!WARNING]
> - **Editing `view` by hand.** The aggregation controller owns the rules of an aggregated ClusterRole and overwrites manual changes. Change the source ClusterRole.
> - **Deleting `system:aggregate-to-view`.** That default ClusterRole gives `view` its normal rules. Remove only the ClusterRole that adds Secrets.
> - **Searching only for ServiceAccount subjects.** A Group subject such as `system:serviceaccounts:<namespace>` or `system:authenticated` grants access to many identities at once.
> - **Removing the legitimate bindings.** `auditor-view` and `dashboard-view` are correct. The problem was in other objects.
