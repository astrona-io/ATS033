---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Close The Kubelet API To Anonymous Callers Solution

Use a host shell with the private kubeconfig for this independent kind environment.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-01" || exit 1
node_name="astro-ats-033-lab-030-03-01-control-plane"
worker_name="astro-ats-033-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers.

Inspect the kubelet configuration on the worker node. The `authentication` and `authorization` blocks decide who may call the kubelet API on port 10250:

```sh
podman exec "$worker_name" grep -A12 '^authentication:' /var/lib/kubelet/config.yaml
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods
```

The request without credentials returns status 200, so any caller who reaches the port can list the pods of the node. Turn anonymous access off and switch authorization to `Webhook`, then restart the kubelet:

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

The worker node is `Ready` again and the request returns status 401, because the kubelet now asks for credentials.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> - **Editing the wrong node.** Change only the worker container of this environment.
> - **Forgetting the restart.** The kubelet reads its configuration file at start. A saved file changes nothing until `systemctl restart kubelet` runs.
> - **Changing only one setting.** Anonymous access off with `AlwaysAllow` still lets every authenticated caller do everything. Change both.
