---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Question

Solve this question on: `terminal`

The `scout` workload in `starfleet-033-040-01-01` collects samples into files and must never create directories or device files. The security team wrote a seccomp profile for it and left the file on the node at `/opt/course/seccomp/scout-guard.json`. The kubelet cannot use the file there, and the pod `scout` does not exist yet.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Install the profile so that the kubelet can load it as the `Localhost` profile `profiles/scout-guard.json`. The cluster has one node, the container `astro-ats-033-lab-040-01-01-control-plane`, and `podman exec` runs a command inside it.
2. Create the pod `scout` in `starfleet-033-040-01-01` with `restartPolicy: Never` and one container that runs `docker.io/library/busybox:1.37.0` with the command `sh -c "sleep 3600"`. The pod must run under the installed profile.
3. Confirm that the process inside `scout` has a seccomp filter, that it can still write a file under `/tmp`, and that `mkdir` fails with `Operation not permitted`.

## Constraints

- Do not change the content of the profile.
- Do not use `Unconfined` or `RuntimeDefault` for `scout`.

## How the answer is checked

The grader runs two checks. First, the file in the kubelet seccomp directory matches the file the security team left, `scout` uses the `Localhost` profile `profiles/scout-guard.json`, `/proc/1/status` reports `Seccomp: 2` and a write under `/tmp` works. Second, `mkdir` inside `scout` fails with `Operation not permitted` while the pod uses that profile.
