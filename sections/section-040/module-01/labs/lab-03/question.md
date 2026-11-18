---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The `scout` Deployment in `starfleet-033-040-01-03` writes a heartbeat file every five seconds. It runs as root with no security settings. The platform team will soon enforce the `restricted` Pod Security level on the namespace, and the security team also wants a read-only root filesystem. `scout` must keep running and stay ready after the change.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Change the `scout` Deployment so that its process runs as user ID `1000` and the kubelet refuses to start it as root.
2. Make the root filesystem of the `scout` container read-only. The application must still write its heartbeat file under `/tmp`, and its pod must become ready.
3. Change the Deployment so that a server-side dry run of `pod-security.kubernetes.io/enforce=restricted` on the namespace reports no violation. Do not add the label for real.

## Constraints

- Keep the Deployment name, the container name `scout`, the image, the command, the readiness probe and one replica.
- Do not change the namespace labels.

## How the answer is checked

The grader first checks that the Deployment keeps its name, container, image, command and one replica, that its rollout is complete, and that exactly one `scout` pod exists, runs and is ready. Then it checks three outcomes: `id -u` in the container does not print `0` and `runAsNonRoot` is `true`; `touch` on a file in `/` fails with `Read-only file system` while a write under `/tmp` works; and `kubectl label --dry-run=server` for the `restricted` level prints no `violate` warning.
