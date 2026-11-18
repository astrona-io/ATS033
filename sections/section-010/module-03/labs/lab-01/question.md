---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

The `starfleet-033-010-03-01` namespace runs the `beacon` Deployment with one replica. Its pod template sets `hostNetwork: true` and `hostPID: true`, runs the container with `privileged: true` and mounts the node directory `/var/log` through a `hostPath` volume named `host-log`. The `beacon` container only needs a writable directory for temporary files.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-01" || exit 1
```

Keep this connection selected. Every script supplied with this task refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Remove host access from the `beacon` pod template: remove `hostNetwork`, `hostPID` and `hostIPC`, and replace the `hostPath` volume with an `emptyDir` volume named `scratch`, mounted at `/scratch`.
2. Make the `beacon` container run without privilege: `privileged: false`, `allowPrivilegeEscalation: false`, `runAsNonRoot: true` with `runAsUser: 10001`, and all capabilities dropped.
3. Give the `beacon` container a read-only root filesystem with `readOnlyRootFilesystem: true`.

## Constraints

- Change only the `beacon` Deployment.
- Keep the Deployment name, the label `app: beacon`, the container name `beacon`, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep 3600"`. One pod must be Running and Ready.

## How the answer is checked

The grader reads the Deployment and runs commands in the running pod with `kubectl exec`. The first check needs no host namespace fields, a pod IP address that differs from the node IP address and no `kubelet` process in the output of `ps`. The second check needs no `hostPath` volume, an `emptyDir` volume mounted at `/scratch` and a file that the container can create there. The third check (2 points) needs the security fields of task 2, either on the container or `runAsUser` on the pod, and `id -u` must print `10001`. The fourth check needs `readOnlyRootFilesystem: true`, and a write to `/` must fail. Every check also needs the original image and command and exactly one Ready `beacon` pod.
