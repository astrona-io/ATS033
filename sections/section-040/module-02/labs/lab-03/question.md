---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Find And Fix A Blocked System Call In A seccomp Profile

Allow about 10 minutes for the tasks.

Solve this question on: `terminal`

The `shuttle` Deployment in `starfleet-033-040-02-03` writes its cargo manifest every five seconds. Since the security team installed a new seccomp profile, the pod keeps restarting. The team wants the pod to run again, but it must still never change the owner of a file.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Find out which operation fails inside the `shuttle` container and which system calls the seccomp profile blocks for it. The profile is `/var/lib/kubelet/seccomp/profiles/cargo-guard.json` on the node, which is the container `astro-ats-033-lab-040-02-03-control-plane`.
2. Change the profile so that the failing operation works again, and keep the rule that blocks `chown`, `fchown`, `fchownat` and `lchown`.
3. Make the `shuttle` Deployment run one ready pod under the changed profile.

## Constraints

- Keep the `Localhost` seccomp profile on `shuttle`. Do not use `Unconfined` or `RuntimeDefault`.
- Do not change the container command, the image or the number of replicas.
- Keep `SCMP_ACT_ALLOW` as the default action of the profile.

## How the answer is checked

The grader first checks that `shuttle` keeps its container, image, command and one replica, that exactly one pod is ready, that the pod uses a `Localhost` profile whose file exists on the node, and that `/proc/1/status` in the container reports `Seccomp: 2`. Then it checks two outcomes. First, the profile file keeps `SCMP_ACT_ALLOW` as the default action, and a command inside the pod can rename a file with `mv`. Second, `chown` on a file inside the pod still fails with `Operation not permitted`.
