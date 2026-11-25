---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Enforce The Baseline Pod Security Standard

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

The `outpost-033-010-03-02` namespace has no Pod Security Admission label, so the API server admits any pod there, privileged or not. The `tracker` Deployment in that namespace sets `hostPID: true`, although the `tracker` container does not need to see the processes of the node. The team wants the namespace to reject pods that ask for host access, and `tracker` must keep running.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-02" || exit 1
```

Keep this connection selected. Every script supplied with this task refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Remove `hostPID` from the `tracker` pod template, and wait until the new pod is Ready.
2. Label the namespace `outpost-033-010-03-02` with `pod-security.kubernetes.io/enforce=baseline`.

## Constraints

- Keep the Deployment name, the label `app: tracker`, the image and the command.
- Do not set the enforce level to `privileged`, and do not add an exemption.

## How the answer is checked

The first check needs the namespace label `pod-security.kubernetes.io/enforce=baseline`. It then sends a privileged pod to the API server with `kubectl run --dry-run=server`, and Pod Security Admission must reject it. A server-side dry run checks the request with every admission step but stores nothing. The second check needs a `tracker` template without `hostNetwork`, `hostPID`, `hostIPC` or a privileged container, the original image, a complete rollout and no running `tracker` pod that uses a host namespace.
