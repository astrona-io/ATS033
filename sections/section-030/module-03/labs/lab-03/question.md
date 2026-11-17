---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

The kubelet is the agent on each node that runs pods. It serves an HTTPS API on port 10250. On the worker node of this cluster, someone set the kubelet to accept requests without credentials and to allow every request. Anyone who can reach port 10250 on that node can list its pods, and any ServiceAccount token is enough to do more.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-03" || exit 1
node_name="astro-ats-033-lab-030-03-03-control-plane"
worker_name="astro-ats-033-lab-030-03-03-worker"
```

Keep this connection selected. Run node commands with `podman exec "$worker_name" <command>`.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. In `/var/lib/kubelet/config.yaml` on the worker node, turn off anonymous authentication for the kubelet.
2. In the same file, set the kubelet authorization mode to `Webhook`, so the kubelet asks the API server whether each caller may do what it asks.
3. Restart the kubelet so it loads the file, and confirm that the worker node is `Ready` again.

## Constraints

- Change only the kubelet on the worker node. Do not change the control-plane node.
- Keep webhook authentication enabled, so the kubelet still accepts bearer tokens and checks them with the API server.

## How the answer is checked

The grader reads the running kubelet configuration through `kubectl get --raw /api/v1/nodes/<worker>/proxy/configz`. It expects `authentication.anonymous.enabled` to be `false`, `authentication.webhook.enabled` to be `true` and `authorization.mode` to be `Webhook`. From inside the worker node it sends `curl -sk https://127.0.0.1:10250/pods`: without credentials the answer must be `401`, and with a token for the ServiceAccount `metrics-reader` in `starfleet-033-030-03-03`, which has no RBAC permissions, the answer must be `403`. The worker node must be `Ready`.
