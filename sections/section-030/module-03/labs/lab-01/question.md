---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Close The Kubelet API To Anonymous Callers

A node was set up for debugging. Its kubelet accepts anonymous requests and allows every request it receives. Anyone who can reach port 10250 of that node can list its pods.

## Starting state

The cluster has one control-plane node and one worker node. The kubelet on the worker node has `authentication.anonymous.enabled` set to `true` and `authorization.mode` set to `AlwaysAllow` in `/var/lib/kubelet/config.yaml`. The node is `Ready`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-01" || exit 1
node_name="astro-ats-033-lab-030-03-01-control-plane"
worker_name="astro-ats-033-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

On the worker node, set `authentication.anonymous.enabled` to `false` and `authorization.mode` to `Webhook` in `/var/lib/kubelet/config.yaml`, and restart the kubelet. Keep `authentication.webhook.enabled` as it is. The worker node must be `Ready`, and an unauthenticated request to `https://127.0.0.1:10250/pods` from inside the worker container must return status 401.

## Verify The Result

The grader checks the resource fields and live requests. Wait for the changes to settle, then repeat your own test requests before you submit.
