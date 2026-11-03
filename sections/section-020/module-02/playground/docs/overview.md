---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Guided Practice: Replace A Wildcard Role And cluster-admin Binding

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-02" || exit 1
```

Keep this connection selected. This playground needs no access to the nodes.

## Inspect And Explain

The `ops-agent` ServiceAccount in `starfleet` has a wildcard Role and a binding to `cluster-admin`. It only needs to read pods and pod logs in `starfleet`. Inspect what binds it:

```sh
kubectl -n starfleet get role ops-wide -o yaml
kubectl -n starfleet get rolebinding ops-wide -o wide
kubectl get clusterrolebinding ops-agent-admin -o wide
```

Create the Role `ops-agent-reader` with `get` and `list` on `pods` and `get` on `pods/log`, bind it to the ServiceAccount with a RoleBinding of the same name, and delete the old Role, RoleBinding and ClusterRoleBinding. Save each object to a file first, then apply it.

## Verify The Result

Ask the API server as the ServiceAccount. A `no` ends with a nonzero status, so run the commands one at a time.

```sh
account=system:serviceaccount:starfleet:ops-agent
kubectl auth can-i list pods --as="$account" -n starfleet
kubectl auth can-i delete pods --as="$account" -n starfleet
kubectl auth can-i list pods --as="$account" -n outpost
kubectl auth can-i --list --as="$account" -n starfleet
```

## Common pitfalls

> [!WARNING]
> Deleting only the Role leaves the `cluster-admin` binding in place. Test as the ServiceAccount with `--as`, never as yourself.
