---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The ServiceAccount `ops-agent` in `starfleet-033-020-02-02` has far too much access. The RoleBinding `ops-wide` binds it to the Role `ops-wide`, which allows every verb on every resource in the namespace. The ClusterRoleBinding `ops-agent-admin` also binds it to `cluster-admin`. The agent only needs to read Pods and their logs in `starfleet-033-020-02-02`.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-02" || exit 1
```

Keep this connection selected. Every script of the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Delete the ClusterRoleBinding `ops-agent-admin`.
2. Delete the RoleBinding `ops-wide` and the Role `ops-wide` in `starfleet-033-020-02-02`.
3. Create the Role `ops-agent-reader` in `starfleet-033-020-02-02` with exactly these permissions: `get` and `list` on `pods`, and `get` on `pods/log`. Bind it to `ops-agent` with a RoleBinding named `ops-agent-reader`.

## Constraints

- `ops-agent-reader` must be the only binding of `ops-agent`, and the Role must not use wildcards or `resourceNames`.
- Do not change or delete the ServiceAccount `ops-agent` and do not change the ClusterRole `cluster-admin`.

## How the answer is checked

The grader runs three checks. The first check confirms that `ops-agent-admin` is gone, that no ClusterRoleBinding names `ops-agent`, and that `kubectl auth can-i` answers `no` for listing nodes and for listing Pods in `outpost-033-020-02-02`. The second check confirms that the RoleBinding and the Role `ops-wide` are gone and that no Role bound to `ops-agent` has a wildcard. The third check compares the rules of `ops-agent-reader` with the exact list above and expects an exact `yes` for the three read requests and `no` for deleting Pods, `create pods/exec`, reading Secrets and creating Deployments.
