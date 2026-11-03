---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Replace A Wildcard Role And cluster-admin Binding

Replace a wildcard Role and a cluster-admin binding with a narrow Role.

## Starting state

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The `ops-agent` ServiceAccount in `starfleet` is bound to a Role `ops-wide` that allows every verb on every resource, and to `cluster-admin` through the ClusterRoleBinding `ops-agent-admin`. The agent only needs to read pods and their logs in `starfleet`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Remove every route by which the `ops-agent` ServiceAccount in `starfleet` has wildcard or cluster-wide authority. Then give it exactly this access in the `starfleet` namespace: `get` and `list` on `pods`, and `get` on `pods/log`. Name the new Role `ops-agent-reader` and its RoleBinding `ops-agent-reader`.

After the change, `kubectl auth can-i` as the ServiceAccount must answer `yes` for listing pods, getting pods and getting pod logs in `starfleet`. It must answer `no` for deleting pods, getting secrets and creating deployments in `starfleet`, for listing pods in `outpost`, and for listing nodes. The old Role `ops-wide`, the old RoleBinding `ops-wide` and the ClusterRoleBinding `ops-agent-admin` must no longer exist. Do not change the workloads.

## Verify The Result

The grader checks the required object fields and the answers of `kubectl auth can-i`. Wait for the rollout to finish before you submit. Preserve the namespaces, workload names and unrelated components.
