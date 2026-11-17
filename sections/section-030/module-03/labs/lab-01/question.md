---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A change to the control-plane node widened the listener of kube-scheduler. Port 10259 now answers on every address of the node, and the pod `shuttle` in `starfleet-033-030-03-01` on the worker node can reach it. Only the node itself needs this port, for health checks and metrics.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-01" || exit 1
node_name="astro-ats-033-lab-030-03-01-control-plane"
worker_name="astro-ats-033-lab-030-03-01-worker"
```

Keep this connection selected. Run node commands with `podman exec "$node_name" <command>`.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Change the kube-scheduler static pod manifest on the control-plane node so that kube-scheduler listens on `127.0.0.1` only.
2. Confirm that kube-scheduler still answers `ok` on `https://127.0.0.1:10259/healthz` from inside the control-plane node.
3. Confirm that a request from `shuttle` to port 10259 on the control-plane node's InternalIP is refused.

## Constraints

- Change only the bind address. Keep every other flag of kube-scheduler.
- Do not add a firewall rule and do not stop kube-scheduler.

## How the answer is checked

The grader reads the command line of the running kube-scheduler process and expects `--bind-address=127.0.0.1`. It reads the listeners of the control-plane node with `ss` and expects port 10259 on `127.0.0.1` only, and it expects `ok` from the local health check. Then it sends a request from `shuttle` to port 10259 on the control-plane node's InternalIP, which must fail with `Connection refused`. A guard checks that the kube-scheduler pod is Ready.
