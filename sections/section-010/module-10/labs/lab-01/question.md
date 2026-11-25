---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close An Unneeded Listener On A Node

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

A security scan of the cluster reports that the node accepts connections on TCP port `8099` on every address. Kubernetes does not use this port. Some systemd service on the node opens it, and nobody on the team owns that service.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-01-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-01-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. On the node, find the process that listens on TCP port `8099` and the systemd service that started it.
2. Stop that service, so that nothing listens on port `8099` any more.
3. Make sure the service does not start again when the node boots. Disabling it, masking it or removing its unit file are all accepted.

## Constraints

- Change only the service that opens port `8099`. Do not stop, disable or mask any other unit.
- The `kubelet` and `containerd` services must stay active, and the API server readiness endpoint `/readyz` must answer `ok`.
- Killing the process is not enough: the service restarts it after two seconds.

## How the answer is checked

The grader runs two checks on the node. The first check reads the active state of the service and lists the listening TCP sockets with `ss`: the service must not run, and no process may listen on port `8099`. The second check reads the load state and the unit file state of the service: it must be `disabled` or `masked`, or the unit file must be gone (`not-found`). Every check also confirms that `kubelet` and `containerd` are active and that `/readyz` answers `ok`.
