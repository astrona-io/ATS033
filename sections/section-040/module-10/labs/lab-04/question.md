---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Fix A Pod That References A Missing seccomp Profile

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

The `shuttle` Deployment in `starfleet-033-040-01-04` was changed to run under the approved seccomp profile, and now its pod does not start. The security team says the profile is installed on the node. The workload must run again under that profile, and `chmod` must stay blocked.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-04" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Find out why the `shuttle` pod does not start. Use the pod status and its events. The cluster has one node, the container `astro-ats-033-lab-040-01-04-control-plane`, and `podman exec` runs a command inside it.
2. Fix the `shuttle` Deployment so that its pod runs under the approved profile `shuttle-guard.json` in the kubelet seccomp directory.
3. Confirm that the process inside the running pod has a seccomp filter and that `chmod` on a file under `/tmp` fails with `Operation not permitted`.

## Constraints

- Keep the Deployment name, the container name `shuttle`, the image, the command and one replica.
- Keep a `Localhost` seccomp profile. Do not use `Unconfined` or `RuntimeDefault`.
- Do not change the content of the approved profile.

## How the answer is checked

The grader first checks that the Deployment keeps its name, container, image, command and one replica, that its rollout is complete, that exactly one `shuttle` pod exists and runs, and that its effective seccomp profile is a `Localhost` profile with the same content as `shuttle-guard.json`. Then it checks two outcomes: `/proc/1/status` in the pod reports `Seccomp: 2`, and `chmod` on a file under `/tmp` fails with `Operation not permitted`.
