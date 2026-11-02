---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Grant One Host Identity Scoped Read Access

Grant a dedicated host identity access to one report without granting root access.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-01" || exit 1
node_name="astro-ats-033-lab-020-01-01-control-plane"
worker_name="astro-ats-033-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Add training-reader to training-readers so it can read public-report. Keep private-report root-only and both files owned by root. Record identity-review with identity training-reader and result scoped-read. The account must remain a non-root UID, must not join the root group and must be denied reading private-report.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
