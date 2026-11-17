---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

In `starfleet-033-020-02-03`, the user `auditor` and the ServiceAccount `dashboard` each have the ClusterRole `view` through a RoleBinding. `view` is meant to be read-only and to exclude Secrets. A review found two problems. First, `auditor` can read the Secret `bridge-credentials`, although no binding names a Secret rule for it. Second, `dashboard` and even the `default` ServiceAccount of the namespace can create Deployments. Find the objects that cause both problems and remove them.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-02-03" || exit 1
```

Keep this connection selected. Every script of the lab refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the ClusterRole that adds Secret access to the ClusterRole `view`, and remove it, so that `kubectl auth can-i get secrets --as=auditor -n starfleet-033-020-02-03` answers `no`.
2. Find the binding that gives every ServiceAccount of `starfleet-033-020-02-03` the ClusterRole `edit`, and delete it.

## Constraints

- Do not edit the ClusterRole `view` directly and do not remove its `aggregationRule`.
- Keep the RoleBindings `auditor-view` and `dashboard-view`. Both subjects must still read Pods and ConfigMaps in the namespace.

## How the answer is checked

The grader runs two checks with `kubectl auth can-i` and expects an exact `yes` or `no`. The first check confirms that the rules of `view` and of every ClusterRole with the label `rbac.authorization.k8s.io/aggregate-to-view=true` grant no Secrets, and that `auditor` cannot get or list Secrets. The second check confirms that no binding gives `edit`, `admin` or `cluster-admin` to the group of all ServiceAccounts, that the `default` ServiceAccount cannot list Pods, and that `dashboard` cannot create Deployments or delete Pods. Both checks also confirm that `auditor` and `dashboard` keep their read access.
