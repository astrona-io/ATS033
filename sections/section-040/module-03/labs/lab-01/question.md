---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Remove Privileged Mode And Keep One Capability

Remove privileged mode from a Deployment, drop all capabilities and keep only the one it needs. Use the isolated `starfleet` environment to verify the result.

## Objective

Remove privileged mode from a Deployment, drop all capabilities and keep only the one it needs.

## Starting state

The Deployment `relay` in `starfleet` was started with `privileged: true` and escalation allowed, as root, with the full set of capabilities. The only privileged operation it ever needs is listening on a port below 1024.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

Change Deployment `relay` in `starfleet` and keep its name, selector, image and command. Its pod must set `runAsNonRoot: true`, `runAsUser: 1000` and `RuntimeDefault` seccomp. Its container `relay` must set `privileged: false` and `allowPrivilegeEscalation: false`, drop `ALL` capabilities and add back only `NET_BIND_SERVICE`. The running pod must show `CapBnd` as `0000000000000400`, `NoNewPrivs: 1` and `Seccomp: 2` in `/proc/1/status`, and the Deployment rollout must be complete.

## Verify The Result

The grader checks the stated resource fields and live evidence from inside the running container. Wait for the controller to converge before submitting. Inspect actual results rather than relying on a sample transcript.
