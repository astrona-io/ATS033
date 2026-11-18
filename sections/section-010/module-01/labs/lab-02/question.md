---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

A review of the Kubernetes node finds a program called `/usr/sbin/debug-relay`. It runs as a systemd service and serves the node's `/var/log` directory over HTTP on `127.0.0.1:7070`. Somebody installed it from a package while debugging an old outage. The node does not need it any more.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-01-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the node, find the Debian package that owns `/usr/sbin/debug-relay`, and check that no other installed package depends on it.
2. Remove that package with the package manager, so that its program and its service are gone and nothing listens on TCP port `7070`.
3. Remove the package's configuration files as well, so that the package database keeps no record of it.

## Constraints

- Use the package manager (`apt-get` or `dpkg`). Do not delete the package's files by hand.
- Remove only this package. The node has no network access, so do not install or upgrade anything.
- The `kubelet` and `containerd` services must stay active, the node must stay `Ready`, and the API server readiness endpoint `/readyz` must answer `ok`.

## How the answer is checked

The grader runs two checks on the node. The first check reads the package status with `dpkg-query`: the package must not be installed, `/usr/sbin/debug-relay` must not exist, and no process may listen on port `7070`. The second check needs `dpkg-query` to find no record of the package, or a `not-installed` status, and the configuration file `/etc/debug-relay/relay.conf` must be gone. Every check also confirms that `kubelet` and `containerd` are active, that the node is `Ready` and that `/readyz` answers `ok`.
