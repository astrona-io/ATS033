---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Guided Practice: Remove Host Access From A Workload

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-010-03" || exit 1
```

Keep this connection selected. Every script supplied with this task refuses a different context.

## Inspect And Explain

Read what the Deployment asks for before you change it. The first command prints the pod template fields that give host access. The second shows the node address next to the pod address; a pod on the host network has the same address as its node.

```sh
kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.hostPID} {.spec.template.spec.containers[0].securityContext.privileged}{"\n"}'
kubectl -n starfleet get pods -l app=beacon -o wide
```

Do not label the namespace first. The `baseline` standard rejects the pods of the current template, so a replacement pod would never be created after the label. Fix the template first.

Change only the `beacon` Deployment and the `starfleet` namespace.

1. Remove `hostNetwork`, `hostPID` and `hostIPC` from the pod template.
2. Replace the `hostPath` volume with an `emptyDir` volume named `scratch`, mounted at `/scratch`.
3. Make the container run without privilege: `privileged: false`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true` with `runAsUser: 10001`, and all capabilities dropped.
4. After the new pod runs, label the `starfleet` namespace `pod-security.kubernetes.io/enforce=baseline`.
5. Create the ConfigMap `workload-review` in the `starfleet` namespace with the data `workload: beacon` and `result: hardened`.

Keep the Deployment name, the label `app: beacon`, the container name `beacon`, the image and the command. One replica must be ready.

Save this as `deployment-beacon.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beacon
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: beacon
  template:
    metadata:
      labels:
        app: beacon
    spec:
      containers:
      - name: beacon
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 10001
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: scratch
          mountPath: /scratch
      volumes:
      - name: scratch
        emptyDir: {}
```

Save this as `configmap-workload-review.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workload-review
  namespace: starfleet
data:
  workload: beacon
  result: hardened
```

Apply the Deployment, wait for the rollout, then label the namespace and record the review:

```sh
kubectl apply -f deployment-beacon.yaml
kubectl -n starfleet rollout status deployment/beacon --timeout=120s
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl apply -f configmap-workload-review.yaml
```

## Verify The Result

Check the template, the running pod and the label. A server-side dry run of the same label shows whether any pod in the namespace would still violate the standard.

```sh
kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.volumes}{"\n"}'
kubectl -n starfleet get pods -l app=beacon -o wide
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite --dry-run=server
kubectl get --raw=/readyz
```

The first command prints an empty host network value and no volumes of type `hostPath`. The pod address now differs from the node address, and the readiness endpoint answers `ok`.

## Common pitfalls

> [!WARNING]
> - Label the namespace after the new pod runs. With the label first, the Deployment is accepted but its ReplicaSet cannot create pods.
> - Setting only `privileged: false` is not enough. The host namespaces and the `hostPath` volume stay, and `baseline` rejects them.
> - `readOnlyRootFilesystem: true` needs a writable volume for any path the container writes to. The `emptyDir` volume `scratch` provides it.
> - Confirm the private context before every change.
