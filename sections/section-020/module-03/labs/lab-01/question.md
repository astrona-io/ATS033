---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The `monitor` Deployment in `starfleet-033-020-03-01` does not call the Kubernetes API, yet it runs with the `default` ServiceAccount, which receives a mounted token and has a RoleBinding `default-pod-lister`. A long-lived token Secret `legacy-monitor-token` also exists. The namespace also runs two healthy `probe` replicas, an internal Service and two client pods.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Give `monitor` its own identity: create the ServiceAccount `monitor` with `automountServiceAccountToken: false`, and make the Deployment use it with `automountServiceAccountToken: false` in the pod template. After the rollout, the pod must have no token directory at `/var/run/secrets/kubernetes.io/serviceaccount`.
2. Close the `default` ServiceAccount: set `automountServiceAccountToken: false` on it and delete the RoleBinding `default-pod-lister`, so it has no binding of any kind.
3. Delete the long-lived token Secret `legacy-monitor-token`.
4. Prove the result: as the `default` and `monitor` ServiceAccounts, `kubectl auth can-i` must answer `no` for listing pods and for getting secrets in `starfleet-033-020-03-01`.

## Constraints

- Keep the `probe` Deployment, the `legacy-monitor` ServiceAccount and the other pods unchanged.
- Preserve the namespaces, the workload names and every unrelated component.

## How the answer is checked

The grader runs three checks: the one `monitor` pod runs as the `monitor` ServiceAccount, has no mounted token, and the ServiceAccount cannot list pods; the `default` ServiceAccount mounts no token, has no binding and cannot list pods or get secrets; and the Secret `legacy-monitor-token` is gone. Wait for the rollout to finish before you submit.
