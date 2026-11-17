---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

In `starfleet-033-020-03-02`, the Deployment `relay` runs as the ServiceAccount `relay`. It sends its token to one service, `bridge-api`, and to nothing else. Today the Pod receives the default token, which the Kubernetes API server accepts and which lives about one hour. Give `relay` a short-lived token that is valid only for `bridge-api`, and remove the default token.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-02" || exit 1
```

Keep this connection selected. Every script of the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Add a projected volume with a `serviceAccountToken` source to the Deployment `relay`. Mount it at `/var/run/secrets/tokens`, so the token file is `/var/run/secrets/tokens/bridge-token`. Set the audience to `bridge-api` and the lifetime to 600 seconds.
2. Stop the automatic mount of the default token in the `relay` Pod.

## Constraints

- Keep the ServiceAccount `relay` and one replica.
- Do not create a Secret for the token.

## How the answer is checked

The grader reads `/var/run/secrets/tokens/bridge-token` inside the running `relay` Pod and decodes the JSON Web Token (JWT). It expects the audience (`aud`) to be exactly `bridge-api`, the expiry time (`exp`) minus the issue time (`iat`) to be 600 seconds, and the ServiceAccount to be `relay`. A second check runs `ls` inside the Pod and expects `/var/run/secrets/kubernetes.io/serviceaccount` to be absent.
