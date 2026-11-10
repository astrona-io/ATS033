---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The `ops-agent` ServiceAccount in `starfleet-033-020-02-01` is bound to a Role `ops-wide` that allows every verb on every resource, and to `cluster-admin` through the ClusterRoleBinding `ops-agent-admin`. The agent only needs to read pods and their logs in `starfleet-033-020-02-01`. The namespace also runs two healthy `probe` replicas, an internal Service and two client pods.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Remove the cluster-wide authority: delete the ClusterRoleBinding `ops-agent-admin`.
2. Remove the wildcard authority: delete the RoleBinding `ops-wide` and the Role `ops-wide`.
3. Give `ops-agent` exactly this access in `starfleet-033-020-02-01`: `get` and `list` on `pods`, and `get` on `pods/log`. Name the new Role `ops-agent-reader` and its RoleBinding `ops-agent-reader`.
4. Prove the result with `kubectl auth can-i` as the ServiceAccount: `yes` for listing pods, getting pods and getting pod logs in `starfleet-033-020-02-01`; `no` for deleting pods, getting secrets and creating deployments there, for listing pods in `outpost-033-020-02-01`, and for listing nodes.

## Constraints

- Remove every route by which `ops-agent` has wildcard or cluster-wide authority.
- Do not change the workloads or the ServiceAccount itself.
- Preserve the namespaces, the workload names and every unrelated component.

## How the answer is checked

The grader runs three checks: `ops-agent` has no binding to `cluster-admin` and cannot list nodes or pods in `outpost-033-020-02-01`; the RoleBinding `ops-wide` is gone and no Role bound to `ops-agent` has a wildcard; and the RoleBinding `ops-agent-reader` gives exactly the read access above, with `kubectl auth can-i` answering `no` for the other requests.
