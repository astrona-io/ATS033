---
exam_objectives:
- Using least-privilege identity and access management
---
# Mount A Short-Lived Projected Token Solution

Select the private cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-02" || exit 1
```

## 1. Look at the default token

```sh
kubectl -n starfleet-033-020-03-02 exec deploy/relay -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
ca.crt
namespace
token
```

The default token also comes from a projected volume that the API server adds to the Pod. Its source shows no audience and a lifetime of about one hour:

```sh
kubectl -n starfleet-033-020-03-02 get pod -l app=relay -o jsonpath='{.items[0].spec.volumes[0].projected.sources[0]}'
```

```text
{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}}
```

Without an audience, the token is meant for the Kubernetes API server. Anyone who steals it can call the API server as `relay`.

## 2. Add the projected token and turn off the default one

The kubelet asks the API server for a token with the given audience and lifetime, writes it to the file and renews it before it expires. Save this as `deployment-relay.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: relay
  namespace: starfleet-033-020-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: relay
  template:
    metadata:
      labels:
        app: relay
    spec:
      serviceAccountName: relay
      automountServiceAccountToken: false
      containers:
      - name: relay
        image: docker.io/library/busybox:1.37.0
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: bridge-token
          mountPath: /var/run/secrets/tokens
          readOnly: true
      volumes:
      - name: bridge-token
        projected:
          sources:
          - serviceAccountToken:
              path: bridge-token
              expirationSeconds: 600
              audience: bridge-api
```

Apply it:

```sh
kubectl apply -f deployment-relay.yaml
kubectl -n starfleet-033-020-03-02 rollout status deployment/relay --timeout=180s
```

```text
deployment.apps/relay configured
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
deployment "relay" successfully rolled out
```

Then check the result:

```sh
kubectl -n starfleet-033-020-03-02 exec deploy/relay -- ls /var/run/secrets/tokens
kubectl -n starfleet-033-020-03-02 exec deploy/relay -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
bridge-token
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```

## 3. Read the claims in the token

A JWT has three parts separated by dots. The middle part holds the claims in base64url encoding. These commands take that part, turn it into normal base64, add the missing padding and decode it:

```sh
token_payload=$(kubectl -n starfleet-033-020-03-02 exec deploy/relay -- cat /var/run/secrets/tokens/bridge-token | cut -d. -f2 | tr '_-' '/+')
while [ $(( ${#token_payload} % 4 )) -ne 0 ]; do token_payload="$token_payload="; done
echo "$token_payload" | base64 -d | python3 -m json.tool
```

The output below is shortened. The `jti` field and the `kubernetes.io` block with the Pod, node and ServiceAccount details are left out:

```text
{
    "aud": [
        "bridge-api"
    ],
    "exp": 1794953432,
    "iat": 1794952832,
    "iss": "https://kubernetes.default.svc.cluster.local",
    "nbf": 1794952832,
    "sub": "system:serviceaccount:starfleet-033-020-03-02:relay"
}
```

`exp` minus `iat` is 600 seconds, and `aud` lists only `bridge-api`. The API server rejects this token, because its audience is not the API server.

Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-03-02`.

## Common pitfalls

> [!WARNING]
> - **Mounting over the default path.** If the volume uses `/var/run/secrets/kubernetes.io/serviceaccount`, the grader sees a token there. Use `/var/run/secrets/tokens`.
> - **A lifetime under 600 seconds.** The API server rejects `expirationSeconds` below 600.
> - **Putting the audience on the ServiceAccount.** The audience belongs to the `serviceAccountToken` source in the Pod template.
> - **Setting automount on the ServiceAccount only.** That also works, but a Pod-level value wins over it. Setting it in the Pod template keeps the change with the workload.
