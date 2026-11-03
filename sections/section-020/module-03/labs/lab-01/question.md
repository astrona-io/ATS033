---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Give A Workload Its Own ServiceAccount And Remove Its Tokens

Use a dedicated ServiceAccount without a mounted token and remove the unused token paths.

## Starting state

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The `monitor` Deployment in `starfleet` runs with the `default` ServiceAccount, which receives a mounted token and has a RoleBinding `default-pod-lister`. A long-lived token Secret `legacy-monitor-token` also exists.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

The `monitor` Deployment in `starfleet` does not call the Kubernetes API. Give it a dedicated ServiceAccount named `monitor` with `automountServiceAccountToken: false`, and make the Deployment use it with `automountServiceAccountToken: false` in the pod template. After the rollout, the pod must have no token directory at `/var/run/secrets/kubernetes.io/serviceaccount`.

Then close the other token paths in `starfleet`. The `default` ServiceAccount must have `automountServiceAccountToken: false` and no binding of any kind, so delete the RoleBinding `default-pod-lister`. Delete the long-lived token Secret `legacy-monitor-token`. As the `default` and `monitor` ServiceAccounts, `kubectl auth can-i` must answer `no` for listing pods and for getting secrets in `starfleet`. Keep the `probe` Deployment, the `legacy-monitor` ServiceAccount and the other pods unchanged.

## Verify The Result

The grader checks the required object fields and the answers of `kubectl auth can-i`. Wait for the rollout to finish before you submit. Preserve the namespaces, workload names and unrelated components.
