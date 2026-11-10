---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

The control-plane node container of this environment runs an extra systemd service, `training-extra.service`, that Kubernetes does not need. It is active and enabled. The `starfleet-033-010-01-01` namespace runs two healthy `probe` replicas, an internal Service and two client pods.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-01" || exit 1
node_name="astro-ats-033-lab-010-01-01-control-plane"
worker_name="astro-ats-033-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 5 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the control-plane node, stop `training-extra.service`.
2. Disable `training-extra.service` so that it does not start at boot.
3. Record the change: create the ConfigMap `host-review` in the namespace `starfleet-033-010-01-01` with the data `service: training-extra.service` and `result: disabled`.

## Constraints

- Change only `training-extra.service` on the control-plane node container. This is a scoped host-service exercise, not a full host hardening assessment.
- The `kubelet` and `containerd` services must stay active, and the API readiness endpoint must answer.
- Preserve the namespace, the workload names and every unrelated component.

## How the answer is checked

The grader runs three checks: `training-extra.service` is inactive; it is disabled; and the ConfigMap `host-review` has the required data. Every check also confirms that `kubelet` and `containerd` are active and that the API answers `/readyz`.

Hint: run `systemctl` inside the node container, for example `podman exec "$node_name" systemctl status training-extra.service`.
