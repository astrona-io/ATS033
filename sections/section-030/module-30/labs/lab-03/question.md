---
exam_objectives:
- Minimize external access to the network
---
# Close The Kubelet API To Anonymous Callers

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

The kubelet is the agent on each node that runs pods. It serves an HTTPS API on port 10250. On the node of this cluster, someone set the kubelet to accept requests without credentials and to allow every request. Anyone who can reach port 10250 on that node can list its pods, and any ServiceAccount token is enough to do more.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-03-03`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. In `/var/lib/kubelet/config.yaml` on the node, turn off anonymous authentication for the kubelet.
2. In the same file, set the kubelet authorization mode to `Webhook`, so the kubelet asks the API server whether each caller may do what it asks.
3. Restart the kubelet so it loads the file, and confirm that the node is `Ready` again.

## Constraints

- Change only the kubelet configuration file. Do not change the static pod manifests of the control plane.
- Keep webhook authentication enabled, so the kubelet still accepts bearer tokens and checks them with the API server.

## How the answer is checked

The grader reads the running kubelet configuration through `kubectl get --raw /api/v1/nodes/<node>/proxy/configz`. It expects `authentication.anonymous.enabled` to be `false`, `authentication.webhook.enabled` to be `true` and `authorization.mode` to be `Webhook`. On the node it sends `curl -sk https://127.0.0.1:10250/pods`: without credentials the answer must be `401`, and with a token for the ServiceAccount `metrics-reader` in `starfleet-033-030-03-03`, which has no RBAC permissions, the answer must be `403`. The node must be `Ready`.
