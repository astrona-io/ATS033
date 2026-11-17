---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A security scan of the control-plane node reports that the etcd data directory is readable by every user on the node. etcd stores every Kubernetes object in this directory, including all Secrets. The directory must be readable by its owner only, and etcd must keep running.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-04" || exit 1
node_name="astro-ats-033-lab-030-03-04-control-plane"
worker_name="astro-ats-033-lab-030-03-04-worker"
```

Keep this connection selected. Run node commands with `podman exec "$node_name" <command>`.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the etcd data directory from the `--data-dir` flag in the etcd static pod manifest on the control-plane node.
2. Set the mode of that directory to `700`. Keep the owner `root:root`.
3. Confirm that etcd still reports itself healthy and that the API server is ready.

## Constraints

- Do not move, copy or delete the data directory.
- Do not change the etcd manifest.

## How the answer is checked

The grader runs `stat` on `/var/lib/etcd` on the control-plane node and expects mode `700` with owner and group `root`. Guards check that etcd answers its `/health` endpoint with `"health":"true"` when called with the API server's etcd client certificate, and that `kubectl get --raw /readyz` returns `ok`.
