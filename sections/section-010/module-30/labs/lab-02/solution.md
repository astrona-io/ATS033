---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Enforce The Baseline Pod Security Standard Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-02" || exit 1
```

## Test the label before you set it

Pod Security Admission is a step in the API server that checks every new pod against a Pod Security Standard. The namespace label `pod-security.kubernetes.io/enforce` chooses the standard: `privileged` allows everything, `baseline` blocks known ways to reach the host, and `restricted` adds more rules. The API server checks pods only when they are created. Pods that already run stay.

A server-side dry run of the label shows which running pods would break the new rule, without changing the namespace:

```sh
kubectl get namespace outpost-033-010-03-02 --show-labels
kubectl label --dry-run=server --overwrite namespace outpost-033-010-03-02 pod-security.kubernetes.io/enforce=baseline
```

```text
NAME                    STATUS   AGE   LABELS
outpost-033-010-03-02   Active   13s   kubernetes.io/metadata.name=outpost-033-010-03-02
Warning: existing pods in namespace "outpost-033-010-03-02" violate the new PodSecurity enforce level "baseline:latest"
Warning: tracker-78bb984bc8-2vpn8: host namespaces
namespace/outpost-033-010-03-02 labeled (server dry run)
```

The namespace has no Pod Security label. The `tracker` pod violates `baseline` because it uses a host namespace (`hostPID: true`). If you set the label now, the running pod stays, but the ReplicaSet controller cannot create a replacement when the pod is deleted or the node fails. So fix the workload first. Your pod name will differ.

## Fix the tracker Deployment

The new template is the old one without `hostPID`. Save this as `deployment-tracker.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tracker
  namespace: outpost-033-010-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tracker
  template:
    metadata:
      labels:
        app: tracker
    spec:
      containers:
      - name: tracker
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
```

Apply it:

```sh
kubectl apply -f deployment-tracker.yaml
```

Then check the result:

```sh
kubectl -n outpost-033-010-03-02 rollout status deployment/tracker --timeout=120s
kubectl -n outpost-033-010-03-02 get pods -l app=tracker
```

```text
Waiting for deployment "tracker" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "tracker" rollout to finish: 1 old replicas are pending termination...
deployment "tracker" successfully rolled out
NAME                       READY   STATUS        RESTARTS   AGE
tracker-78bb984bc8-2vpn8   1/1     Terminating   0          21s
tracker-7f6bfbc557-gtm2q   1/1     Running       0          1s
```

The new pod runs. The old pod is still terminating for a few seconds.

## Enforce baseline

Set the label for real:

```sh
kubectl label namespace outpost-033-010-03-02 pod-security.kubernetes.io/enforce=baseline
```

```text
Warning: existing pods in namespace "outpost-033-010-03-02" violate the new PodSecurity enforce level "baseline:latest"
Warning: tracker-78bb984bc8-2vpn8: host namespaces
namespace/outpost-033-010-03-02 labeled
```

The warning names the old pod `tracker-78bb984bc8-2vpn8`, which was still terminating when this run set the label. The API server sets the label anyway, because warnings never block a label. If you wait until the old pod is gone, the label command prints only the last line.

Then check the result. The label is on the namespace, and only the new pod runs:

```sh
kubectl -n outpost-033-010-03-02 get pods -l app=tracker
kubectl get namespace outpost-033-010-03-02 --show-labels
```

```text
NAME                       READY   STATUS    RESTARTS   AGE
tracker-7f6bfbc557-gtm2q   1/1     Running   0          19s
NAME                    STATUS   AGE   LABELS
outpost-033-010-03-02   Active   39s   kubernetes.io/metadata.name=outpost-033-010-03-02,pod-security.kubernetes.io/enforce=baseline
```

## Prove that the rule blocks privileged pods

A label is only useful if the API server acts on it. Send a privileged pod with a server-side dry run, which runs every admission step but stores nothing. Save this as `pod-privileged-test.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-test
  namespace: outpost-033-010-03-02
spec:
  containers:
  - name: privileged-test
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      privileged: true
```

Apply it as a dry run:

```sh
kubectl apply --dry-run=server -f pod-privileged-test.yaml
```

```text
Error from server (Forbidden): error when creating "pod-privileged-test.yaml": pods "privileged-test" is forbidden: violates PodSecurity "baseline:latest": privileged (container "privileged-test" must not set securityContext.privileged=true)
```

The output is shortened: the real message shows the full path of the file. The API server rejects the pod with `Forbidden` and names the rule: `PodSecurity "baseline:latest"` and the field `securityContext.privileged=true`.

## Common pitfalls

> [!WARNING]
> - **Labelling first and never fixing the workload.** The old pod keeps running, so nothing looks wrong. The next replacement pod fails, and only the ReplicaSet events show `FailedCreate`.
> - **Using `warn` or `audit` instead of `enforce`.** Those modes only report. Only `enforce` rejects pods.
> - **Expecting Pod Security Admission to stop a Deployment.** The API server checks pods. A Deployment with a bad template is stored with a warning, and its pods are rejected later.
