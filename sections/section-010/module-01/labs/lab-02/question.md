---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

A review of the control-plane node finds a program called `/usr/sbin/debug-relay`. It runs as a systemd service and serves the node's `/var/log` directory over HTTP on `127.0.0.1:7070`. Somebody installed it from a package while debugging an old outage. The node does not need it any more.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-02" || exit 1
node_name="astro-ats-033-lab-010-01-02-control-plane"
worker_name="astro-ats-033-lab-010-01-02-worker"
```

Keep this connection selected. Each node of the cluster is a container on your machine, so `podman exec "$node_name" <command>` runs a command on the control-plane node. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the control-plane node, find the Debian package that owns `/usr/sbin/debug-relay`, and check that no other installed package depends on it.
2. Remove that package with the package manager, so that its program and its service are gone and nothing listens on TCP port `7070`.
3. Remove the package's configuration files as well, so that the package database keeps no record of it.

## Constraints

- Use the package manager (`apt-get` or `dpkg`). Do not delete the package's files by hand.
- Remove only this package. The node has no network access, so do not install or upgrade anything.
- The `kubelet` and `containerd` services must stay active on both nodes, every node must stay `Ready`, and the API server readiness endpoint `/readyz` must answer `ok`.

## How the answer is checked

The grader runs two checks on the control-plane node. The first check reads the package status with `dpkg-query`: the package must not be installed, `/usr/sbin/debug-relay` must not exist, and no process may listen on port `7070`. The second check needs `dpkg-query` to find no record of the package, or a `not-installed` status, and the configuration file `/etc/debug-relay/relay.conf` must be gone. Every check also confirms that `kubelet` and `containerd` are active on both nodes, that every node is `Ready` and that `/readyz` answers `ok`.
