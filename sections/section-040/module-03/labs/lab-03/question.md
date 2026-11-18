---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The Deployment `relay` in `starfleet-033-040-03-03` serves a status page on port 80. It was started with `privileged: true` and with privilege escalation allowed. The only privileged operation it needs is listening on a port below 1024, and it must keep running as root.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. In the container `relay`, stop running as privileged and block privilege escalation.
2. Drop all Linux capabilities and add back only `NET_BIND_SERVICE`.
3. Wait for the rollout, then confirm in the running pod that `CapBnd` and `CapEff` in `/proc/1/status` are `0000000000000400` and that `NoNewPrivs` is `1`.
4. Confirm that the page on port 80 still answers `relay-ok` and that `chown` on `/www/index.html` now fails.

## Constraints

- Keep the Deployment name, selector, image, command and one replica.
- Do not set `runAsUser` or `runAsNonRoot`. The task is about capabilities, and the process stays user ID 0.

## How the answer is checked

The grader first checks that `relay` keeps its container, image, command and one replica, and that exactly one pod is ready. Then it checks three outcomes. First, the container is not privileged and `/proc/1/status` reports `NoNewPrivs: 1`. Second, `CapBnd` and `CapEff` are both `0000000000000400`. Third, `wget` inside the pod reads `relay-ok` from port 80, and `chown 1000 /www/index.html` fails with `Operation not permitted`.
