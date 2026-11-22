---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Apply The RuntimeDefault seccomp Profile To Deployments

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

An audit of `starfleet-033-040-02-01` found two Deployments that run without any seccomp filter. `bridge` never set a profile, and `scout` runs as a privileged container. Both must run under the container runtime's default seccomp profile.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Check the `Seccomp:` line in `/proc/1/status` of every pod in the namespace and note the value.
2. Change both Deployments so that their pods use the seccomp profile type `RuntimeDefault`.
3. Make sure that every pod of both Deployments reports `Seccomp: 2`. Change whatever stops a pod from getting the filter.

## Constraints

- Keep the Deployment names, container names, images, commands and replica counts (`bridge` 2, `scout` 1).
- Do not use `Localhost` or `Unconfined` profiles.

## How the answer is checked

For each Deployment, the grader checks that the name, container, image, command and replica count are unchanged and that the rollout is complete. Then it checks every pod of that Deployment: the pod runs, its container is not privileged, its effective seccomp profile type is `RuntimeDefault`, and `/proc/1/status` reports `Seccomp: 2`. One outcome covers `bridge`, the other covers `scout`.
