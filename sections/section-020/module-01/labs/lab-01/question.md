---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

This lab runs a virtual machine (VM) with a one-node Kubernetes cluster. The VM is the node: it runs the control plane and the workloads. The node keeps the flight log `/srv/flight-logs/telemetry.log`. Today every account on the node can read it, because the file is `root:root` with mode `644`. Only the account `navigator` should read the log, and it should get that access through the existing group `flight-log-readers`. The account `cadet` is another normal account on the same node.

Open a shell on the lab VM and confirm the cluster:

```sh
astrona ssh astro-ats-033-lab-020-01-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-020-01-01`. You are logged in as the `student` user. Node files belong to `root`, so run the commands that change them with `sudo`. They change only the lab VM, not your own computer.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the node, change `/srv/flight-logs/telemetry.log` so that its owner stays `root`, its group is `flight-log-readers`, the group can read it and other accounts have no access at all.
2. Add `navigator` to the group `flight-log-readers` so that `navigator` can read the log. Keep every other group of `navigator`.

## Constraints

- Grant no other access. Do not add `navigator` or `cadet` to any other group, do not change their UIDs and do not change the file's content.
- Do not use the root account or the root group to grant the access.

## How the answer is checked

The grader runs two checks on the node. The first check reads the log as `navigator` with `runuser` and confirms that `navigator` belongs only to its own group and `flight-log-readers`. The second check confirms that the file is `root:flight-log-readers`, that other accounts have no permission bits, and that a read as `cadet` fails with `Permission denied`. Both checks also confirm that both accounts still exist with a non-root UID and that `root` still owns the file.
