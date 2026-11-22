---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close Unused And Duplicate Root Accounts

Allow about 8 minutes for the tasks.

Solve this question on: `terminal`

An account review of a Kubernetes node finds two problems. The account `olduser` belongs to a person who left the team years ago, but it still has a password and the shell `/bin/bash`. A second account, `toor`, has the user identifier (UID) 0, so the kernel treats it as root. Administrators use the account `opsadmin`, which must keep working.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-02-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run commands that read passwords or change accounts with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Give `olduser` the login shell `/usr/sbin/nologin`, so that no login can start a shell for it.
2. Lock the password of `olduser`. Keep the account itself.
3. Make sure that `root` is the only account with UID 0. Remove `toor`, or give it a UID that is not 0.

## Constraints

- Do not change `root` or `opsadmin`: `opsadmin` keeps its UID, the shell `/bin/bash` and its usable password.
- `kubelet` and `containerd` must stay active, and the API server readiness endpoint `/readyz` must answer `ok`.

## How the answer is checked

The grader reads the accounts with `getent passwd` on the node. The first check needs a refusing shell for `olduser` (`nologin` or `false`) and runs `su olduser -c true`, which must fail. The second check needs `passwd -S olduser` to report the status `L` (locked). The third check lists every account with UID 0 and needs only `root`. Every check also confirms that `opsadmin` still has a non-zero UID, `/bin/bash` and the status `P`, that `kubelet` and `containerd` are active and that `/readyz` answers `ok`.
