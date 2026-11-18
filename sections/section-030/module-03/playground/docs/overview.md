---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Guided Practice: Close The Kubelet API To Anonymous Callers

The playground is a VM (virtual machine) that runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the VM and check that kubectl uses the playground cluster:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-030-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-playground-030-03`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the playground VM, not your own computer.

## Starting state

The `starfleet` namespace runs two `probe` replicas behind the `probe` Service and the `shuttle` client pod. The `outpost` namespace runs the `drifter` client pod. The kubelet on the node has `authentication.anonymous.enabled` set to `true` and `authorization.mode` set to `AlwaysAllow` in `/var/lib/kubelet/config.yaml`.

## Task

Set `authentication.anonymous.enabled` to `false` and `authorization.mode` to `Webhook` in `/var/lib/kubelet/config.yaml`, and restart the kubelet. Keep `authentication.webhook.enabled` as it is. The node must be `Ready`, and an unauthenticated request to `https://127.0.0.1:10250/pods` on the node must return status 401.

## Inspect, change and verify

Inspect the kubelet configuration. The `authentication` and `authorization` blocks decide who may call the kubelet API on port 10250:

```sh
sudo grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

The file shows `enabled: true` under `anonymous` and `mode: AlwaysAllow`. The request without credentials returns status `200`, so any caller who reaches the port can list the pods of the node. Turn anonymous access off and switch authorization to `Webhook`, then restart the kubelet:

```sh
sudo sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
sudo sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
```

Wait a few seconds for the kubelet to start, then check the result:

```sh
kubectl get nodes
sudo grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

The node is `Ready` again, the file shows `enabled: false` under `anonymous` and `mode: Webhook`, and the request returns status `401`, because the kubelet now asks for credentials.

## Common pitfalls

> [!WARNING]
> - **Forgetting `sudo`.** The kubelet configuration file belongs to root. Without `sudo`, `sed -i` fails with `Permission denied` and nothing changes.
> - **Forgetting the restart.** The kubelet reads its configuration file at start. A saved file changes nothing until `systemctl restart kubelet` runs.
> - **Changing only one setting.** Anonymous access off with `AlwaysAllow` still lets every authenticated caller do everything. Change both.
