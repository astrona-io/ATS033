---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Kubelet API Authentication And Authorization

The kubelet is the agent that runs on every node and starts the containers. It also serves an HTTPS API on port 10250, which the API server uses for `kubectl logs` and `kubectl exec`. A kubelet that accepts anonymous callers and allows every request gives an attacker the same view of the node that the API server has, with no Kubernetes credential at all. This part shows the three settings that control the kubelet API, finds an unsafe configuration in the playground, and repairs it.

## The three settings

The kubelet reads its settings from a configuration file, `/var/lib/kubelet/config.yaml` on a kubeadm node. Three blocks decide who may call port 10250.

- `authentication.anonymous.enabled` decides whether a request without credentials is accepted as the user `system:anonymous`. It must be `false`.
- `authentication.webhook.enabled` lets the kubelet check bearer tokens by sending a TokenReview request to the API server. `authentication.x509.clientCAFile` lets it accept client certificates signed by the cluster certificate authority. The API server authenticates to the kubelet with such a certificate.
- `authorization.mode` decides what an authenticated caller may do. `AlwaysAllow` allows everything. `Webhook` makes the kubelet send a SubjectAccessReview request to the API server, so the normal RBAC rules apply to requests such as `nodes/proxy`, `nodes/log` and `nodes/metrics`.

The kubelet API serves paths such as `/pods`, `/logs`, `/metrics` and `/run`. The path `/run` runs a command in a container. With anonymous access on and `AlwaysAllow`, an unauthenticated caller can use it.

## Why both settings are needed

Anonymous access off with `AlwaysAllow` still lets every caller with any valid credential do everything on the node. Anonymous access on with `Webhook` leaves each request to RBAC, which is safe only if no role is bound to `system:anonymous`. The two settings protect different steps, so set both. One more setting, `readOnlyPort`, opens an unauthenticated read-only port (10255) when it is not zero. The default is `0`, which is off.

## Find the unsafe setting

Select the environment and read the authentication and authorization blocks of the worker node:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-030-03" || exit 1
worker_name="astro-ats-033-playground-030-03-worker"
podman exec "$worker_name" grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
```

The playground set the kubelet of the worker node to a debugging configuration. The block shows `enabled: true` under `anonymous`, and the `authorization` block shows `mode: AlwaysAllow`. Now call the kubelet API from inside the worker container, without a certificate or a token. The option `-k` skips the certificate check, and `-w '%{http_code}'` prints only the status:

```sh
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
podman exec "$worker_name" curl -sk https://127.0.0.1:10250/pods | head -c 300
```

The first command prints `200`. The second prints the beginning of a JSON list of all pods on the node. Any caller that can reach the port gets this list. In a real cluster, that caller can also use `/run` to run commands in any container on the node.

## Repair the kubelet

The repair changes two settings in the file and restarts the kubelet, because the kubelet reads the file only at start. The first command sets `enabled` to `false` in the lines from `authentication:` to the first `webhook:` line, which covers only the `anonymous` block. The second command restores the authorization mode.

```sh
podman exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" systemctl restart kubelet
```

Then check the result. Wait a few seconds for the kubelet to start before the request:

```sh
kubectl get nodes
podman exec "$worker_name" grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

The worker node returns to `Ready`, the file shows `enabled: false` under `anonymous`, and the request now prints `401`. The kubelet no longer accepts a caller without credentials. The API server still reaches it, because it presents a client certificate that the kubelet trusts.

## What can break

A monitoring system that scrapes `/metrics` with a token needs a ClusterRole that allows `get` on `nodes/metrics`. After you switch to `Webhook`, a scraper without that role gets 403. Add the role before the change. A node that is `NotReady` after a restart almost always has a syntax error in the file, so read it again with `grep` before you restart.

The kubelet port is now closed to anonymous callers. The remaining control-plane component with data of its own is etcd.

## Common pitfalls

> [!WARNING]
> - **Changing only one setting.** Anonymous off with `AlwaysAllow`, or `Webhook` with anonymous on and a bound role, still leaves a gap.
> - **Forgetting the restart.** The file is read at start. A saved change does nothing until `systemctl restart kubelet`.
> - **Editing the control-plane node instead of the worker.** Check the container name before each `podman exec`.
> - **Breaking monitoring.** `Webhook` applies RBAC to `nodes/metrics` and `nodes/log`. Grant those roles to the scrapers first.
