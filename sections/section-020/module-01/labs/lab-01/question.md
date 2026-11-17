---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The control-plane node of this cluster keeps the flight log `/srv/flight-logs/telemetry.log`. Today every account on the node can read it, because the file is `root:root` with mode `644`. Only the account `navigator` should read the log, and it should get that access through the existing group `flight-log-readers`. The account `cadet` is another normal account on the same node.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send. The node is a container, so you run node commands with `podman exec` on that container.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-01" || exit 1
node_name="astro-ats-033-lab-020-01-01-control-plane"
```

Keep this connection selected. Run node commands only on the container named in `node_name`.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Tasks

1. On the control-plane node, change `/srv/flight-logs/telemetry.log` so that its owner stays `root`, its group is `flight-log-readers`, the group can read it and other accounts have no access at all.
2. Add `navigator` to the group `flight-log-readers` so that `navigator` can read the log. Keep every other group of `navigator`.

## Constraints

- Grant no other access. Do not add `navigator` or `cadet` to any other group, do not change their UIDs and do not change the file's content.
- Do not use the root account or the root group to grant the access.

## How the answer is checked

The grader runs two checks on the node. The first check reads the log as `navigator` with `runuser` and confirms that `navigator` belongs only to its own group and `flight-log-readers`. The second check confirms that the file is `root:flight-log-readers`, that other accounts have no permission bits, and that a read as `cadet` fails with `Permission denied`. Both checks also confirm that both accounts still exist with a non-root UID and that `root` still owns the file.
