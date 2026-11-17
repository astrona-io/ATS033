---
exam_objectives:
- Using least-privilege identity and access management
---
# Close The Default ServiceAccount Solution

Select the private cluster and put the user name of the `default` ServiceAccount in a variable:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-03" || exit 1
default_account=system:serviceaccount:starfleet-033-020-03-03:default
```

## 1. Look at the starting state

```sh
kubectl auth can-i list pods --as=$default_account -n starfleet-033-020-03-03
kubectl -n starfleet-033-020-03-03 get rolebindings -o wide
```

```text
yes
NAME           ROLE               AGE   USERS   GROUPS   SERVICEACCOUNTS
default-edit   ClusterRole/edit   44s                    starfleet-033-020-03-03/default
```

The RoleBinding `default-edit` gives `edit` to `default`. Any Pod that names no ServiceAccount gets this access. List the stored tokens too:

```sh
kubectl -n starfleet-033-020-03-03 get secrets --field-selector type=kubernetes.io/service-account-token
```

```text
NAME                   TYPE                                  DATA   AGE
legacy-monitor-token   kubernetes.io/service-account-token   3      44s
```

The token controller in `kube-controller-manager` wrote a token into this Secret. That token has no expiry time, so it works until the Secret is deleted.

## 2. Turn off the automatic token for default

Save this as `serviceaccount-default.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: starfleet-033-020-03-03
automountServiceAccountToken: false
```

Apply it:

```sh
kubectl apply -f serviceaccount-default.yaml
```

```text
Warning: resource serviceaccounts/default is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
serviceaccount/default configured
```

The warning is expected: the ServiceAccount controller created `default`, not `kubectl apply`. Then check the result:

```sh
kubectl -n starfleet-033-020-03-03 get serviceaccount default -o jsonpath='{.automountServiceAccountToken}'
```

```text
false
```

## 3. Delete the binding

```sh
kubectl -n starfleet-033-020-03-03 delete rolebinding default-edit
```

```text
rolebinding.rbac.authorization.k8s.io "default-edit" deleted from starfleet-033-020-03-03 namespace
```

Then check the result:

```sh
kubectl auth can-i list pods --as=$default_account -n starfleet-033-020-03-03
kubectl auth can-i create deployments --as=$default_account -n starfleet-033-020-03-03
```

```text
no
no
```

## 4. Delete the long-lived token

```sh
kubectl -n starfleet-033-020-03-03 delete secret legacy-monitor-token
```

```text
secret "legacy-monitor-token" deleted from starfleet-033-020-03-03 namespace
```

Then check the result:

```sh
kubectl -n starfleet-033-020-03-03 get secrets --field-selector type=kubernetes.io/service-account-token
kubectl -n starfleet-033-020-03-03 get serviceaccounts
```

```text
No resources found in starfleet-033-020-03-03 namespace.
NAME             AGE
default          44s
legacy-monitor   44s
```

`legacy-monitor` still exists. A Pod that runs as it gets a short-lived token from the kubelet, so it does not need the Secret.

Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-03-03`.

## Common pitfalls

> [!WARNING]
> - **Deleting the `default` ServiceAccount.** The ServiceAccount controller creates it again at once. Change it instead.
> - **Thinking automount removes access.** `automountServiceAccountToken: false` only stops the token file. The binding still gives `edit` to anyone who gets a token for `default`. Delete the binding too.
> - **Deleting `legacy-monitor` with its token.** The task removes only the stored token. The ServiceAccount stays.
> - **Checking only names.** Search by type with `--field-selector type=kubernetes.io/service-account-token`, because a token Secret can have any name.
