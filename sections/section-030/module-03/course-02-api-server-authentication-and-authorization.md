---
draft: true
exam_objectives:
- Minimize external access to the network
---
# API Server Authentication And Authorization

Port 6443 must stay reachable, so the network rule cannot be the only control on the API server. The control that remains is the answer to two questions for every request: who is the caller, and is the caller allowed to do this? This part follows a request through authentication and authorization, reads the flags that configure them, and tests the result with a request that carries no credentials.

## Authentication and authorization are separate steps

The API server handles each request in order. **Authentication** decides who the caller is, using a client certificate, a bearer token or another authenticator. **Authorization** decides whether that caller may perform the verb on the resource. **Admission** then validates or changes the object. A request that fails authentication gets status 401. A request that is authenticated and not authorized gets status 403.

The flag `--anonymous-auth` controls what happens to a request with no credentials. When it is `true` (the default), the API server does not reject the request at authentication. It treats the caller as the user `system:anonymous` in the group `system:unauthenticated`, and authorization decides what that user may do. When it is `false`, such a request gets status 401 at once.

The flag `--authorization-mode` is an ordered list of authorizers. The API server asks each in turn. The first one that allows or denies decides, and a request that no authorizer allows is denied. A kubeadm cluster uses `Node,RBAC`. The `Node` authorizer allows each kubelet to read what its own pods need. `RBAC` (role-based access control) allows what Roles and ClusterRoles grant. The mode `AlwaysAllow` allows every request, so it must never run on a real cluster.

## What anonymous users can do by default

With anonymous requests enabled, the question is which ClusterRoles are bound to `system:unauthenticated`. In a default cluster, the ClusterRole `system:public-info-viewer` is bound to that group. It allows reading `/healthz`, `/livez`, `/readyz` and `/version`, and nothing else. Load balancers and bootstrap tools use these paths, which is the reason the default stays on in many clusters. Anything an administrator binds to `system:unauthenticated` or `system:anonymous` extends this list, so the bindings must be reviewed.

## Read the flags

Select the environment and read the relevant flags from the manifest of the API server:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-030-03" || exit 1
node_name="astro-ats-033-playground-030-03-control-plane"
podman exec "$node_name" grep -E 'anonymous-auth|authorization-mode|bind-address|secure-port|client-ca-file' /etc/kubernetes/manifests/kube-apiserver.yaml
```

A line is missing when the manifest does not set the flag, and the default applies. The output shows `--authorization-mode=Node,RBAC`, the client certificate authority file and the secure port 6443. If `--anonymous-auth` does not appear, the default `true` applies.

## Test with a request that has no credentials

The `kind` cluster publishes the API server on a local address. Read it from the kubeconfig and send requests without any credential:

```sh
API_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
curl --insecure --silent --max-time 5 "$API_SERVER/version"
curl --insecure --silent --max-time 5 "$API_SERVER/api/v1/namespaces"
```

The first request returns the version information, because `system:public-info-viewer` allows it. The second request returns a `Status` object with the code 403. Its message says that the user `system:anonymous` cannot list the resource `namespaces`. The option `--insecure` skips the certificate check, which is acceptable only for a local check of your own playground.

You can ask the authorizer the same question without a network request. The `--as` option makes `kubectl` send the request as another user:

```sh
kubectl auth can-i list namespaces --as=system:anonymous
kubectl auth can-i get /version --as=system:anonymous
```

The first answer is `no` and the second is `yes`. If the first answer were `yes`, an administrator would have bound a powerful role to the anonymous user, and the cluster would be open to everyone who can reach port 6443.

## Changing the setting

Setting `--anonymous-auth=false` removes this class of finding, and it has a cost. Health checks of a load balancer that call `/healthz` without credentials start to fail. The command `kubeadm join` reads the ConfigMap `cluster-info` in the namespace `kube-public` without credentials, and it needs anonymous access. Check both before you change the flag. The change itself is an edit of the static pod manifest, after which the kubelet restarts the API server pod.

You now know how the API server treats a caller with no credentials and how to test it. The same questions apply to the kubelet on every node, which has its own API.

## Common pitfalls

> [!WARNING]
> - **Setting `--anonymous-auth=false` without checking dependants.** Health checks and token-based joins may stop working.
> - **Granting a role to `system:unauthenticated` or `system:anonymous`.** The role then applies to everyone who reaches the port.
> - **Using `AlwaysAllow` for a quick test.** Every request, including anonymous ones, is then allowed.
> - **Confusing 401 and 403.** A 401 means the caller is not authenticated. A 403 means the caller is known and not allowed.
