---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

The `starfleet-033-010-03-01` namespace runs the `beacon` Deployment with one replica. Its pod template sets `hostNetwork: true` and `hostPID: true`, runs the container with `privileged: true` and mounts the node directory `/var/log` through a `hostPath` volume named `host-log`. The namespace has no Pod Security Admission label. The `probe` Deployment, the `probe` Service and the `shuttle` and `drifter` pods run normally.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-01" || exit 1
```

Keep this connection selected. Every script supplied with this task refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Remove host access from the `beacon` pod template: remove `hostNetwork`, `hostPID` and `hostIPC`, and replace the `hostPath` volume with an `emptyDir` volume named `scratch`, mounted at `/scratch`.
2. Make the `beacon` container run without privilege: `privileged: false`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true` with `runAsUser: 10001`, and all capabilities dropped.
3. After the new pod runs, label the `starfleet-033-010-03-01` namespace `pod-security.kubernetes.io/enforce=baseline`.
4. Record the change: create the ConfigMap `workload-review` in the namespace `starfleet-033-010-03-01` with the data `workload: beacon` and `result: hardened`.

## Constraints

- Change only the `beacon` Deployment and the `starfleet-033-010-03-01` namespace.
- Keep the Deployment name, the label `app: beacon`, the container name `beacon`, the image and the command. One replica must be ready.
- Preserve the other workloads and every unrelated component.

## How the answer is checked

The grader runs five checks: the pod template and the running pod share no host namespace; the template mounts no `hostPath` volume; the container is not privileged, blocks escalation, requires a non-root user and drops all capabilities; the namespace enforces the baseline standard; and the ConfigMap `workload-review` has the required data. Every check also needs the `beacon` rollout to be complete with exactly one pod.

Hint: label the namespace only after the rollout: the baseline standard rejects the old privileged pod template.
