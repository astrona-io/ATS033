---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The control-plane node of this environment has the account `training-reader`, the group `training-readers` and two report files, `public-report` and `private-report`. Both files are owned by root. `public-report` belongs to the group `training-readers` with mode `640`; `private-report` is root-only with mode `600`. `training-reader` cannot read either file yet. The namespace `starfleet-033-020-01-01` runs two healthy `probe` replicas, an internal Service and two client pods.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-01" || exit 1
node_name="astro-ats-033-lab-020-01-01-control-plane"
worker_name="astro-ats-033-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 5 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the control-plane node, add `training-reader` to the group `training-readers` so that it can read `public-report`.
2. Record the change: create the ConfigMap `identity-review` in the namespace `starfleet-033-020-01-01` with the data `identity: training-reader` and `result: scoped-read`.

## Constraints

- Grant no other access. `training-reader` keeps a non-root UID, does not join the root group and belongs only to its own group and `training-readers`.
- Keep `private-report` root-only (`root:root`, mode `600`) and `public-report` as `root:training-readers` with mode `640`. Reading `private-report` as `training-reader` must still be denied.
- Preserve the namespace, the workload names and every unrelated component.

## How the answer is checked

The grader runs two checks: `training-reader` reads `public-report` through `training-readers` and belongs to no other extra group; and the ConfigMap `identity-review` has the required data. Every check also confirms the non-root identity, the denied read of `private-report` and the owners and modes of both files.
