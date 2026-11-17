---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

An account review of the control-plane node finds two problems. The account `olduser` belongs to a person who left the team years ago, but it still has a password and the shell `/bin/bash`. A second account, `toor`, has the user identifier (UID) 0, so the kernel treats it as root. Administrators use the account `opsadmin`, which must keep working.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-02" || exit 1
node_name="astro-ats-033-lab-010-02-02-control-plane"
worker_name="astro-ats-033-lab-010-02-02-worker"
```

Keep this connection selected. Each node of the cluster is a container on your machine, so `podman exec "$node_name" <command>` runs a command on the control-plane node. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Give `olduser` the login shell `/usr/sbin/nologin`, so that no login can start a shell for it.
2. Lock the password of `olduser`. Keep the account itself.
3. Make sure that `root` is the only account with UID 0. Remove `toor`, or give it a UID that is not 0.

## Constraints

- Do not change `root` or `opsadmin`: `opsadmin` keeps its UID, the shell `/bin/bash` and its usable password.
- `kubelet` and `containerd` must stay active on both nodes, and the API server readiness endpoint `/readyz` must answer `ok`.

## How the answer is checked

The grader reads the accounts with `getent passwd` on the control-plane node. The first check needs a refusing shell for `olduser` (`nologin` or `false`) and runs `su olduser -c true`, which must fail. The second check needs `passwd -S olduser` to report the status `L` (locked). The third check lists every account with UID 0 and needs only `root`. Every check also confirms that `opsadmin` still has a non-zero UID, `/bin/bash` and the status `P`, that `kubelet` and `containerd` are active on both nodes and that `/readyz` answers `ok`.
