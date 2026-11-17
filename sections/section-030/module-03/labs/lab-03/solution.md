---
exam_objectives:
- Minimize external access to the network
---
# Close The Kubelet API To Anonymous Callers Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-03" || exit 1
node_name="astro-ats-033-lab-030-03-03-control-plane"
worker_name="astro-ats-033-lab-030-03-03-worker"
```

Keep this connection selected.

## Step 1: Read the kubelet settings

The kubelet reads its settings from a KubeletConfiguration file, `/var/lib/kubelet/config.yaml` on the node. Two blocks control who may call its API on port 10250. `authentication` decides who the caller is, and `authorization` decides what the caller may do:

```sh
podman exec "$worker_name" sh -c "grep -A8 '^authentication:' /var/lib/kubelet/config.yaml; grep -A1 '^authorization:' /var/lib/kubelet/config.yaml"
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
authorization:
  mode: AlwaysAllow
```

The first `grep` prints eight lines after `authentication:`, so `authorization:` appears twice. `anonymous.enabled: true` lets the kubelet accept a request without credentials as `system:anonymous`. `mode: AlwaysAllow` allows every request without asking the API server.

The file is not always what the kubelet runs. The API server can return the running configuration of a node through the `configz` endpoint. The `python3` filter prints only the two blocks:

```sh
kubectl get --raw "/api/v1/nodes/$worker_name/proxy/configz" | python3 -c 'import json,sys; c=json.load(sys.stdin)["kubeletconfig"]; print(json.dumps({"authentication": c["authentication"], "authorization": c["authorization"]}, indent=2))'
```

```text
{
  "authentication": {
    "x509": {
      "clientCAFile": "/etc/kubernetes/pki/ca.crt"
    },
    "webhook": {
      "enabled": true,
      "cacheTTL": "2m0s"
    },
    "anonymous": {
      "enabled": true
    }
  },
  "authorization": {
    "mode": "AlwaysAllow",
    "webhook": {
      "cacheAuthorizedTTL": "5m0s",
      "cacheUnauthorizedTTL": "30s"
    }
  }
}
```

The running kubelet matches the file.

## Step 2: Prove the exposure

Send a request without credentials to the kubelet from inside the worker node. Then send one with a token for `metrics-reader`, a ServiceAccount that has no RBAC (role-based access control) permissions. `kubectl create token` asks the API server for a short-lived token:

```sh
TOKEN="$(kubectl -n starfleet-033-030-03-03 create token metrics-reader --duration=10m)"
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:10250/pods
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" https://127.0.0.1:10250/pods
```

```text
200
200
```

Both requests get the pod list of the node. Without the status filter, the body starts with `{"kind":"PodList","apiVersion":"v1","metadata":{},"items":[{"metadata":{"name":"kube-proxy-flvrx",` and goes on to list every pod on the worker (shortened here).

## Step 3: Change the file and restart the kubelet

Change the two values with `sed -i`. The first command changes `enabled: true` to `false` only between the `authentication:` line and the `webhook:` line, so the webhook setting stays `true`. The second sets the mode:

```sh
podman exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
```

Both commands print nothing. The kubelet reads the file only when it starts, so restart it with systemd and wait for the node:

```sh
podman exec "$worker_name" systemctl restart kubelet
podman exec "$worker_name" systemctl is-active kubelet
kubectl wait --for=condition=Ready "node/$worker_name" --timeout=120s
```

```text
active
node/astro-ats-033-lab-030-03-03-worker condition met
```

## Step 4: Check the result

Then check the result. Read the running configuration again:

```sh
kubectl get --raw "/api/v1/nodes/$worker_name/proxy/configz" | python3 -c 'import json,sys; c=json.load(sys.stdin)["kubeletconfig"]; print(json.dumps({"authentication": c["authentication"], "authorization": c["authorization"]}, indent=2))'
```

```text
{
  "authentication": {
    "x509": {
      "clientCAFile": "/etc/kubernetes/pki/ca.crt"
    },
    "webhook": {
      "enabled": true,
      "cacheTTL": "2m0s"
    },
    "anonymous": {
      "enabled": false
    }
  },
  "authorization": {
    "mode": "Webhook",
    "webhook": {
      "cacheAuthorizedTTL": "5m0s",
      "cacheUnauthorizedTTL": "30s"
    }
  }
}
```

Repeat the two requests, and print the body of the request with the token:

```sh
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:10250/pods
podman exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" https://127.0.0.1:10250/pods
podman exec "$worker_name" curl -sk -H "Authorization: Bearer $TOKEN" https://127.0.0.1:10250/pods
kubectl get node "$worker_name"
```

```text
401
403
Forbidden (user=system:serviceaccount:starfleet-033-030-03-03:metrics-reader, verb=get, resource=nodes, subresource(s)=[pods proxy])
NAME                                 STATUS   ROLES    AGE   VERSION
astro-ats-033-lab-030-03-03-worker   Ready    <none>   47s   v1.35.0
```

The request without credentials now gets `401 Unauthorized`: the kubelet no longer accepts anonymous callers. The request with the token gets `403 Forbidden`. The kubelet authenticated the token through the API server, then asked the API server with a SubjectAccessReview whether `metrics-reader` may `get` the `nodes` subresource `proxy`. RBAC said no. The node stays `Ready`, because the kubelet reports its status to the API server with its own credentials, and this change does not touch that connection. The `configz` request still works too: the API server calls the kubelet with its own client certificate, and RBAC allows that certificate's user to use the kubelet API.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-03-03`.

## Common pitfalls

> [!WARNING]
> - **Forgetting the restart.** The kubelet reads `/var/lib/kubelet/config.yaml` only when it starts. Check `configz` to see what it really runs.
> - **Turning off webhook authentication.** A blind replace of every `enabled: true` also turns off `webhook.enabled`. Then the kubelet cannot check tokens, and only client certificates work.
> - **Fixing only one block.** Anonymous authentication off with `AlwaysAllow` still lets any valid token do everything. `Webhook` mode with anonymous on still sends `system:anonymous` to RBAC. Change both.
> - **Editing the wrong node.** Each node has its own kubelet and its own file. Run the commands on the node the task names.
