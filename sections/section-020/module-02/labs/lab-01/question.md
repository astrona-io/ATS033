---
exam_objectives:
- Using least-privilege identity and access management
---
# Scope Access With resourceNames And A RoleBinding

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

Two ServiceAccounts need read access in the namespace `starfleet-033-020-02-01`. A ServiceAccount is the Kubernetes identity that a Pod or a tool uses to call the API server. The ServiceAccount `code-reviewer` in `starfleet-033-020-02-01` must read the ConfigMap `probe-code` and nothing else. The ServiceAccount `inspector` lives in another namespace, `outpost-033-020-02-01`. Today it has the ClusterRole `view` through the ClusterRoleBinding `inspector-view`, so it can read every namespace of the cluster.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script of the lab refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. In `starfleet-033-020-02-01`, create the Role `probe-code-reader` that allows only `get` on the ConfigMap named `probe-code`. Bind it to the ServiceAccount `code-reviewer` with a RoleBinding named `code-reviewer`.
2. Give the ServiceAccount `inspector` of `outpost-033-020-02-01` the ClusterRole `view` in `starfleet-033-020-02-01` only. Use a RoleBinding named `inspector-view` in `starfleet-033-020-02-01`, and delete the ClusterRoleBinding `inspector-view`.

## Constraints

- `code-reviewer` must not list or watch ConfigMaps and must not read any other ConfigMap.
- Do not change the ClusterRole `view`, and do not create a ClusterRoleBinding for either ServiceAccount.

## How the answer is checked

The grader runs two checks with `kubectl auth can-i --as=system:serviceaccount:<namespace>:<name>` and expects an exact `yes` or `no`. The first check expects `yes` for `get configmap/probe-code` and `no` for `get configmap/bridge-settings`, for `list`, `watch`, `update` and `delete` on ConfigMaps and for `get secrets`. The second check reads the RoleBinding `inspector-view`, confirms that no ClusterRoleBinding names `inspector`, and expects `yes` for reading Pods and ConfigMaps in `starfleet-033-020-02-01` and `no` in `outpost-033-020-02-01` and `kube-system`.
