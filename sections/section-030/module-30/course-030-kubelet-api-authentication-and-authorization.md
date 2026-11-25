# Kubelet API Authentication And Authorization

The kubelet is the agent that runs on every node and starts the containers. It also serves an HTTPS API on port 10250. The API server uses this API for `kubectl logs` and `kubectl exec`.

A kubelet that accepts anonymous callers and allows every request is a serious risk. It gives an attacker the same view of the node that the API server has, with no Kubernetes credential at all. This page shows the three settings that control the kubelet API. Then you find an unsafe configuration in the playground and repair it.

## The three settings

The kubelet reads its settings from a configuration file. On a kubeadm node, the file is `/var/lib/kubelet/config.yaml`. Three blocks in it decide who may call port 10250:

- `authentication.anonymous.enabled` decides whether the kubelet accepts a request without credentials as the user `system:anonymous`. It must be `false`.
- `authentication.webhook.enabled` lets the kubelet check bearer tokens by sending a TokenReview request to the API server. `authentication.x509.clientCAFile` lets it accept client certificates signed by the cluster certificate authority. The API server authenticates to the kubelet with such a certificate.
- `authorization.mode` decides what an authenticated caller may do. `AlwaysAllow` allows everything. `Webhook` makes the kubelet send a SubjectAccessReview request to the API server. The normal RBAC (role-based access control) rules then apply to requests such as `nodes/proxy`, `nodes/log` and `nodes/metrics`.

The kubelet API serves paths such as `/pods`, `/logs`, `/metrics` and `/run`. The path `/run` runs a command in a container. With anonymous access on and `AlwaysAllow`, an unauthenticated caller can use it.

## Why both settings are needed

The authentication setting and the authorization setting protect different steps. Changing only one of them leaves a gap:

- Anonymous access off with `AlwaysAllow` still lets every caller with any valid credential do everything on the node.
- Anonymous access on with `Webhook` leaves each request to RBAC. That is safe only if no role is bound to `system:anonymous`.

So set both. One more setting, `readOnlyPort`, opens an unauthenticated read-only port (10255) when it is not zero. The default is `0`, which is off.

![Diagram: before the repair, an anonymous request to port 10250 is accepted as system:anonymous and AlwaysAllow returns 200 with the pod list; after the repair, the same request gets 401, while the API server with its client certificate passes authentication and the Webhook check](images/kubelet-before-after.svg)

The drawing compares the two configurations. With anonymous access on and `AlwaysAllow`, any caller gets status 200. With anonymous access off and `Webhook`, an anonymous caller gets 401, and the API server still gets through with its client certificate.

## Find the unsafe setting

Now find the unsafe setting in the playground. Open a shell on the playground VM (virtual machine) and check that `kubectl` uses the playground cluster:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-030-03
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-playground-030-03
```

The VM is the only node of the cluster, so its kubelet is the one to check. The kubelet configuration file belongs to root, so read the authentication and authorization blocks with `sudo`:

```sh
sudo grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
```

```text
authentication:
  anonymous:
    enabled: true
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: AlwaysAllow
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
```

The playground set the kubelet to a debugging configuration. The block shows `enabled: true` under `anonymous`, and the `authorization` block shows `mode: AlwaysAllow`.

Now call the kubelet API without a certificate or a token. This request needs no `sudo`, because any user on the node can open a network connection. The option `-k` skips the certificate check, and `-w '%{http_code}'` prints only the status:

```sh
curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
curl -sk https://127.0.0.1:10250/pods | head -c 300
```

The first command prints `200`. The second prints the beginning of a JSON list of all pods on the node, shortened here to 300 characters:

```text
{"kind":"PodList","apiVersion":"v1","metadata":{},"items":[{"metadata":{"name":"kube-proxy-9rqbr","generateName":"kube-proxy-","namespace":"kube-system","uid":"c59cdb2e-c06a-4cb8-a684-81cffffa3eda","resourceVersion":"370","generation":1,"creationTimestamp":"2026-11-18T08:43:58Z","labels":{"controlle
```

The `student` user sends no Kubernetes credential in this request and still gets the list. Any caller that can reach the port gets it too. In a real cluster, that caller can also use `/run` to run commands in any container on the node.

## Repair the kubelet

The repair changes two settings in the file and then restarts the kubelet. The restart is needed because the kubelet reads the file only when it starts.

- The first command sets `enabled` to `false` in the lines from `authentication:` to the first `webhook:` line. That range covers only the `anonymous` block.
- The second command restores the authorization mode to `Webhook`.
- The third command restarts the kubelet.

```sh
sudo sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
sudo sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
```

The three commands print nothing. Wait a few seconds for the kubelet to start, then check the result:

```sh
kubectl get nodes
sudo grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

```text
NAME                              STATUS   ROLES           AGE     VERSION
astro-ats-033-playground-030-03   Ready    control-plane   4m20s   v1.35.10
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
401
```

The node is `Ready`. The file shows `enabled: false` under `anonymous` and `mode: Webhook`, and the request now prints `401`. The kubelet no longer accepts a caller without credentials. The API server still reaches it, because it presents a client certificate that the kubelet trusts.

## What can break

The `Webhook` mode applies RBAC to every caller, so some callers can lose access. A monitoring system that scrapes `/metrics` with a token needs a ClusterRole that allows `get` on `nodes/metrics`. After you switch to `Webhook`, a scraper without that role gets 403, so add the role before the change.

A node that is `NotReady` after a restart almost always has a syntax error in the file. Read the file again with `grep` before you restart.

You have now closed the kubelet port to anonymous callers and kept the API server path working. The open question is etcd, the remaining control-plane component that holds data of its own.

## Common pitfalls

> [!WARNING]
> - **Changing only one setting.** Anonymous access off with `AlwaysAllow`, or `Webhook` with anonymous access on and a bound role, still leaves a gap.
> - **Forgetting the restart.** The kubelet reads the file at start. A saved change does nothing until `systemctl restart kubelet`.
> - **Editing the wrong node.** Each node has its own kubelet and its own file. In a cluster with several nodes, log in to the node you mean to change before you edit.
> - **Breaking monitoring.** `Webhook` applies RBAC to `nodes/metrics` and `nodes/log`. Grant those roles to the scrapers first.
