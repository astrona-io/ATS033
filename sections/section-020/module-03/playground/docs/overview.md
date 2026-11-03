---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Guided Practice: Give A Workload Its Own ServiceAccount And Remove Its Tokens

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-03" || exit 1
```

Keep this connection selected. This playground needs no access to the nodes.

## Inspect And Explain

The `monitor` Deployment in `starfleet` runs with the `default` ServiceAccount, which has a mounted token and a RoleBinding. A long-lived token Secret also exists. Inspect all three:

```sh
kubectl -n starfleet exec deploy/monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n starfleet get rolebinding default-pod-lister -o wide
kubectl -n starfleet get secrets --field-selector type=kubernetes.io/service-account-token
```

Create the ServiceAccount `monitor` with `automountServiceAccountToken: false`, change the Deployment to use it with the same setting in the pod template, set `automountServiceAccountToken: false` on the `default` ServiceAccount, delete the RoleBinding `default-pod-lister` and delete the Secret `legacy-monitor-token`.

## Verify The Result

```sh
kubectl -n starfleet rollout status deployment/monitor --timeout=180s
kubectl -n starfleet exec deploy/monitor -- sh -c 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo mounted || echo absent'
kubectl auth can-i list pods --as=system:serviceaccount:starfleet:default -n starfleet
kubectl -n starfleet get secrets --field-selector type=kubernetes.io/service-account-token
```

## Common pitfalls

> [!WARNING]
> Setting the field on the ServiceAccount does not change pods that already run. Roll the Deployment so new pods start without the token.
