---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A node was set up for debugging. Its kubelet accepts anonymous requests and allows every request it receives, so anyone who can reach port 10250 of that node can list its pods. The cluster has one control-plane node and one worker node. The kubelet on the worker node has `authentication.anonymous.enabled` set to `true` and `authorization.mode` set to `AlwaysAllow` in `/var/lib/kubelet/config.yaml`. The node is `Ready`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-01" || exit 1
node_name="astro-ats-033-lab-030-03-01-control-plane"
worker_name="astro-ats-033-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the worker node, set `authentication.anonymous.enabled` to `false` in `/var/lib/kubelet/config.yaml`.
2. In the same file, set `authorization.mode` to `Webhook`.
3. Restart the kubelet, and confirm that an unauthenticated request to `https://127.0.0.1:10250/pods` from inside the worker container returns status 401.

## Constraints

- Change only the kubelet configuration of the worker node. Keep `authentication.webhook.enabled` as it is.
- The worker node must be `Ready`.

## How the answer is checked

The grader runs two checks: the worker kubelet configuration disables anonymous authentication and an unauthenticated request returns 401; and its authorization mode is `Webhook`. Every check also needs the worker node to be `Ready`.

Hint: `podman exec "$worker_name" systemctl restart kubelet` restarts the kubelet inside the worker container.
