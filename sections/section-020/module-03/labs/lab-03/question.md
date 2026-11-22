---
exam_objectives:
- Using least-privilege identity and access management
---
# Close The Default ServiceAccount

Allow about 6 minutes for the tasks.

Solve this question on: `terminal`

A review of `starfleet-033-020-03-03` found two old identity risks. Every Pod that does not name a ServiceAccount runs as `default`, and `default` has the ClusterRole `edit` in the namespace. The ServiceAccount `legacy-monitor` also has a long-lived token stored in a Secret, which never expires. Close the `default` ServiceAccount and remove the stored token.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-03" || exit 1
```

Keep this connection selected. Every script of the lab refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Set `automountServiceAccountToken: false` on the ServiceAccount `default` in `starfleet-033-020-03-03`.
2. Delete every RoleBinding or ClusterRoleBinding that names the `default` ServiceAccount of this namespace.
3. Delete every Secret of type `kubernetes.io/service-account-token` in the namespace.

## Constraints

- Keep the ServiceAccount `legacy-monitor`. Workloads can still get short-lived tokens for it.
- Do not delete the ServiceAccount `default`.

## How the answer is checked

The grader runs two checks. The first check reads the ServiceAccount `default`, expects `automountServiceAccountToken` to be `false` and finds no binding that names it. It then asks `kubectl auth can-i` and expects `no` for listing Pods and for creating Deployments as `default`. The second check expects the Secret `legacy-monitor-token` to be gone and no Secret of type `kubernetes.io/service-account-token` to remain. Both checks fail if the ServiceAccount `legacy-monitor` is missing.
