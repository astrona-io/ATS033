---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The account `departed-user` on the control-plane node belongs to a person who has left the team. The account still has a working password, its account never expires and its login shell is `/bin/bash`. The team wants to keep the account and its home directory for an audit, so you must disable it, not delete it. The account `pilot` is still in use and must keep working.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send. The node is a container, so you run node commands with `podman exec` on that container.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-02" || exit 1
node_name="astro-ats-033-lab-020-01-02-control-plane"
```

Keep this connection selected. Run node commands only on the container named in `node_name`.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Lock the password of `departed-user`, so that `passwd -S departed-user` reports the status `L`.
2. Set the account expiry date of `departed-user` to a date in the past, so that the account can no longer start a session.
3. Change the login shell of `departed-user` to `/usr/sbin/nologin`.

## Constraints

- Do not delete `departed-user` or its home directory `/home/departed-user`.
- Do not change the account `pilot`: it keeps its password, its shell `/bin/bash` and no expiry date.

## How the answer is checked

The grader runs three checks on the node. The first check reads the status field of `passwd -S departed-user` and expects `L`. The second check reads the expiry field of `/etc/shadow`, expects a day before today, and confirms that `su` to `departed-user` fails. The third check reads the login shell of `departed-user` and accepts `/usr/sbin/nologin`, `/sbin/nologin` or `/bin/false`. Every check also confirms that `departed-user` and its home directory still exist and that `pilot` is unchanged.
