---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

A security scan of the cluster reports that the control-plane node accepts connections on TCP port `8099` on every address. Kubernetes does not use this port. Some systemd service on the node opens it, and nobody on the team owns that service.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-01" || exit 1
node_name="astro-ats-033-lab-010-01-01-control-plane"
worker_name="astro-ats-033-lab-010-01-01-worker"
```

Keep this connection selected. Each node of the cluster is a container on your machine, so `podman exec "$node_name" <command>` runs a command on the control-plane node. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the control-plane node, find the process that listens on TCP port `8099` and the systemd service that started it.
2. Stop that service, so that nothing listens on port `8099` any more.
3. Make sure the service does not start again when the node boots. Disabling it, masking it or removing its unit file are all accepted.

## Constraints

- Change only the service that opens port `8099`. Do not stop, disable or mask any other unit.
- The `kubelet` and `containerd` services must stay active on both nodes, and the API server readiness endpoint `/readyz` must answer `ok`.
- Killing the process is not enough: the service restarts it after two seconds.

## How the answer is checked

The grader runs two checks on the control-plane node. The first check reads the active state of the service and lists the listening TCP sockets with `ss`: the service must not run, and no process may listen on port `8099`. The second check reads the load state and the unit file state of the service: it must be `disabled` or `masked`, or the unit file must be gone (`not-found`). Every check also confirms that `kubelet` and `containerd` are active on both nodes and that `/readyz` answers `ok`.
