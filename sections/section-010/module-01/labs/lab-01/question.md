---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Disable An Unneeded Node Service

Remove a seeded extra service from active and enabled node services while preserving Kubernetes.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-01" || exit 1
node_name="astro-ats-033-lab-010-01-01-control-plane"
worker_name="astro-ats-033-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Disable and stop only training-extra.service on this private control-plane container. Record host-review with service training-extra.service and result disabled. The extra service must be inactive and disabled, while kubelet and containerd remain active and API readiness succeeds. This is a scoped host-service exercise, not a full host hardening assessment.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
