---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

The control-plane node holds the configuration of its SSH server: the main file `/etc/ssh/sshd_config` and two drop-in files in `/etc/ssh/sshd_config.d/`. The main file looks safe, but the drop-in files loosen it. Administrators log in as `opsadmin`. The node image has no SSH server program installed, so the grader reads the files the same way the SSH server, `sshd`, reads them.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-01" || exit 1
node_name="astro-ats-033-lab-010-02-01-control-plane"
worker_name="astro-ats-033-lab-010-02-01-worker"
```

Keep this connection selected. Each node of the cluster is a container on your machine, so `podman exec "$node_name" <command>` runs a command on the control-plane node. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Refuse root logins: make the first `PermitRootLogin` value that `sshd` reads `no`.
2. Refuse password logins: make the first `PasswordAuthentication` value that `sshd` reads `no`, and keep `PubkeyAuthentication yes`.
3. Allow only `opsadmin` to log in with an `AllowUsers` line that applies to every connection, not only to the connections of a `Match` block.

## Constraints

- Keep the `Include` line, the `Match User backup` block and the `opsadmin` account with the shell `/bin/bash`.
- `kubelet` and `containerd` must stay active on both nodes, and the API server readiness endpoint `/readyz` must answer `ok`.

## How the answer is checked

The grader reads `/etc/ssh/sshd_config` in the order `sshd` reads it. Each `Include` line pulls in its files at that position, in alphabetical order. Keywords do not depend on upper or lower case, and for each keyword the first value read wins. Settings after a `Match` line belong to that block until the next `Match` line or the end of the file, so they are not global. The first check needs `PermitRootLogin no`. The second check needs `PasswordAuthentication no` and `PubkeyAuthentication yes`. The third check needs global `AllowUsers` lines that list only `opsadmin`. Every check also confirms that `opsadmin` keeps `/bin/bash`, that `kubelet` and `containerd` are active on both nodes and that `/readyz` answers `ok`.
