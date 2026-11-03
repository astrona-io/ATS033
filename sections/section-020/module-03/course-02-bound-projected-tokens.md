---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Bound Projected Tokens

A token that never expires is a permanent credential. If it leaks, it stays valid until someone finds the leak and deletes the ServiceAccount. Earlier Kubernetes versions created such tokens automatically in Secrets. Current versions issue short-lived tokens that are tied to the pod they were issued for. This part explains how they work, how to set their lifetime and audience, and how to request one by hand for a script or a test.

## What bound means

A **bound** token is a JWT that the API server issues through the TokenRequest API and ties to an object, usually the pod. The token carries an expiry time and the name and UID of the pod. When the pod is deleted, the API server rejects the token even if the expiry has not passed. The kubelet requests the token for the pod, writes it into a **projected volume**, which is a volume that combines data from several sources, and refreshes it before it expires. The default lifetime is one hour for a token requested through a projected volume. The kubelet starts to refresh a token when it has used 80 percent of its lifetime.

Since Kubernetes 1.24 the control plane no longer creates a token Secret for each ServiceAccount. Since version 1.22 the default token in a pod is a bound projected token. A token also has an **audience**, which names the service that should accept it. The API server accepts tokens whose audience includes its own identity. Another service, such as a vault or a registry, can require a token with its own audience. A token for the wrong audience fails there.

## Project a token with a short lifetime

You can ask the kubelet for an extra token with your own lifetime and audience by adding a `serviceAccountToken` source to a projected volume. A workload that calls a different service then holds a token meant only for that service. The minimum `expirationSeconds` is 600, which is ten minutes.

Select the playground first:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-020-03" || exit 1
```

Save this as `serviceaccount-token-client.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: token-client
  namespace: starfleet
automountServiceAccountToken: false
```

Save this as `pod-token-client.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: token-client
  namespace: starfleet
spec:
  serviceAccountName: token-client
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    volumeMounts:
    - name: probe-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: probe-token
    projected:
      sources:
      - serviceAccountToken:
          path: probe-token
          audience: probe
          expirationSeconds: 600
```

Apply both:

```sh
kubectl apply -f serviceaccount-token-client.yaml -f pod-token-client.yaml
```

Then check the result. The standard mount is off, and the projected file exists with content:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/token-client --timeout=120s
kubectl -n starfleet exec token-client -- sh -c 'test -s /var/run/secrets/tokens/probe-token && echo present || echo absent'
kubectl -n starfleet exec token-client -- sh -c 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo mounted || echo absent'
```

The commands print `present` and `absent`. The pod has one token for the audience `probe` with a ten-minute lifetime and no general API token.

## Request a short-lived token by hand

For a script, a test or a one-time job, use `kubectl create token`. The command calls the TokenRequest API for the ServiceAccount and prints a JWT that is not stored anywhere in the cluster. The option `--duration` sets the lifetime, and `--bound-object-kind` and `--bound-object-name` bind it to a pod or Secret.

```sh
kubectl -n starfleet create token token-client --duration=10m
```

The command prints one long line, which is the token. Anyone who holds the line can act as `token-client` until it expires, so treat it like a password and never write it in a repository or a log. The token only proves who the caller is. Because `token-client` has no RoleBinding, the API server would refuse every request made with it, and that refusal comes from RBAC, not from the token.

You now know that pod tokens expire, are tied to a pod and can carry a limited audience. Older clusters and some scripts still leave behind long-lived tokens and the `default` identity. The last part removes those.

## Common pitfalls

> [!WARNING]
> - **Setting `expirationSeconds` below 600.** The API server refuses the request.
> - **Copying a token into a ConfigMap or an image.** A token printed once can be used until it expires. Request it at run time.
> - **Using the wrong audience.** The receiving service rejects a token whose audience does not match its own.
> - **Assuming a bound token works after the pod is gone.** Deleting the pod invalidates the token.
