---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Enforce Limits With Pod Security Admission

A reviewer can catch a privileged pod in one manifest, but a cluster has many teams and many manifests. The cluster needs a rule that the API server applies to every pod, whoever writes it. Pod Security Admission is that rule. This lesson explains the three standards it enforces, the three modes it runs in, and the surprise that catches many administrators: a Deployment is accepted even when its pods are rejected.

## Standards, levels and modes

Pod Security Admission is an admission controller built into the API server. An admission controller checks a request after authentication and authorization and before the object is stored. Pod Security Admission checks every pod against one of three **Pod Security Standards**, chosen by labels on the namespace:

- **`privileged`** allows everything.
- **`baseline`** blocks the known routes to host access: `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` volumes, host ports, privileged containers and extra capabilities beyond a short safe list.
- **`restricted`** includes `baseline` and adds hardening rules. A container must set `allowPrivilegeEscalation: false`, run as a non-root user (`runAsNonRoot: true`), drop all capabilities, use a seccomp profile of type `RuntimeDefault` or `Localhost`, and use only a short list of volume types.

A label sets one level for one **mode**. The label key is `pod-security.kubernetes.io/<mode>` and its value is the level. The mode `enforce` makes the API server reject a pod that violates the level. The mode `warn` accepts the pod and returns a warning to the user. The mode `audit` accepts the pod and records an audit event. A common rollout sets `warn` and `audit` first to learn what would break, and `enforce` after that.

## Preview a label before you apply it

A server-side dry run of the label command shows what would break without changing the namespace. Run the dry run against the `starfleet` namespace, which holds the `beacon` Deployment with host access:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-010-03" || exit 1
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --dry-run=server --overwrite
```

The command returns warnings for pods in `starfleet` that already violate `baseline`. The `beacon` pod appears in the warnings, because it uses the host namespaces, a privileged container and a `hostPath` volume. Pods that do not violate the level produce no warning. The dry run changed nothing. This is the safe first step before any `enforce` label.

## A Deployment is accepted while its pods are rejected

Apply a Deployment that violates `baseline` to a namespace that enforces it, and watch where the rejection happens. First label `outpost`:

```sh
kubectl label namespace outpost pod-security.kubernetes.io/enforce=baseline
```

Save this as `deployment-scanner.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner
  namespace: outpost
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanner
  template:
    metadata:
      labels:
        app: scanner
    spec:
      hostPID: true
      containers:
      - name: scanner
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
```

Apply it:

```sh
kubectl apply -f deployment-scanner.yaml
```

Then check the result:

```sh
kubectl -n outpost get deployment scanner
kubectl -n outpost get events --field-selector reason=FailedCreate
```

The `apply` command succeeds, and the Deployment shows no ready replica. Pod Security Admission checks pods, not Deployments. The Deployment object passes, and the ReplicaSet controller then tries to create the pod and receives the rejection. The controller records the failure as a `FailedCreate` event on the ReplicaSet. The message names `PodSecurity`, the level `baseline` and the field that violates it, `hostPID`.

```mermaid
flowchart TB
    A["kubectl apply"] -->|"Deployment: accepted"| B["API server"]
    B --> C["ReplicaSet controller"]
    C -->|"creates pod"| D["Pod Security Admission"]
    D -->|"hostPID: rejected"| E["Event: FailedCreate"]
```

The diagram shows that the rejection happens when the ReplicaSet controller creates the pod, so the user sees a success from `kubectl apply` and must read the events to find the error.

## Fix the template and read the result

The correction is in the pod template, not in the namespace. Remove `hostPID` and add the container settings that `restricted` expects, which also satisfy `baseline`. Save this as `deployment-scanner.yaml`, replacing the earlier file:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner
  namespace: outpost
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanner
  template:
    metadata:
      labels:
        app: scanner
    spec:
      containers:
      - name: scanner
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 10001
          capabilities:
            drop:
            - ALL
```

Apply it, wait for the rollout and remove the experiment:

```sh
kubectl apply -f deployment-scanner.yaml
kubectl -n outpost rollout status deployment/scanner --timeout=120s
kubectl -n outpost delete deployment scanner
kubectl label namespace outpost pod-security.kubernetes.io/enforce-
```

The rollout completes, because the new pod passes the level. The last command removes the label with the trailing dash.

Two limits matter. The `enforce` mode checks pods when they are created or updated, so a pod that already runs is not removed. Pods in system namespaces such as `kube-system` legitimately use host namespaces, so a cluster administrator exempts them in the admission configuration or leaves their namespaces without an `enforce` label.

You now know how the cluster rejects host access and where the error appears. Two parts of the node's own protection remain: the kubelet API that the pods depend on, and the choice of which nodes sensitive pods may share.

## Common pitfalls

> [!WARNING]
> - **Reading `deployment created` as success.** A rejected pod shows up as a `FailedCreate` event and a Deployment with no ready replicas. Read the events of the ReplicaSet.
> - **Labelling first and fixing later.** After an `enforce` label, a replacement pod of a violating Deployment cannot be created. Fix the template first and label after.
> - **Expecting `enforce` to remove running pods.** It affects new and updated pods only.
> - **Labelling system namespaces.** Components in `kube-system` need host access. Use `warn` and `audit` there, or exempt them.
