---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Remove Host Access From A Workload

Rewrite a Deployment that shares the host namespaces, mounts a host directory and runs privileged, then enforce the baseline Pod Security Standard on its namespace.

## Starting state

The `starfleet` namespace runs the `beacon` Deployment with one replica. Its pod template sets `hostNetwork: true` and `hostPID: true`, runs the container with `privileged: true` and mounts the node directory `/var/log` through a `hostPath` volume named `host-log`. The namespace has no Pod Security Admission label. The `probe` Deployment, the `probe` Service and the `shuttle` and `drifter` pods run normally.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-01" || exit 1
```

Keep this connection selected. Every script supplied with this task refuses a different context.

## Required result

Change only the `beacon` Deployment and the `starfleet` namespace.

1. Remove `hostNetwork`, `hostPID` and `hostIPC` from the pod template.
2. Replace the `hostPath` volume with an `emptyDir` volume named `scratch`, mounted at `/scratch`.
3. Make the container run without privilege: `privileged: false`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true` with `runAsUser: 10001`, and all capabilities dropped.
4. After the new pod runs, label the `starfleet` namespace `pod-security.kubernetes.io/enforce=baseline`.
5. Create the ConfigMap `workload-review` in the `starfleet` namespace with the data `workload: beacon` and `result: hardened`.

Keep the Deployment name, the label `app: beacon`, the container name `beacon`, the image and the command. One replica must be ready.

## Verify The Result

The grader reads the Deployment template, the running pod, the namespace labels and the ConfigMap. Wait for the rollout to finish before you submit. Preserve the other workloads and every unrelated component.
