---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

The account `leaver` has left the flight operations team. The person still has access in four places: membership of the node group `flight-ops`, which can read `/srv/flight-ops/roster`, a sudo rule in `/etc/sudoers.d`, Kubernetes RBAC (role-based access control) bindings for the user name `leaver`, and a working password. The account `crew-member` is still on the team and must keep all of its access.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send. The node is a container, so you run node commands with `podman exec` on that container.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-03" || exit 1
node_name="astro-ats-033-lab-020-01-03-control-plane"
```

Keep this connection selected. Run node commands only on the container named in `node_name`.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Remove `leaver` from the group `flight-ops`, so that `leaver` can no longer read `/srv/flight-ops/roster`.
2. Remove every sudo rule for `leaver` from the node.
3. Delete every RoleBinding and ClusterRoleBinding that names the user `leaver`, so that `kubectl auth can-i ... --as=leaver` answers `no`.
4. Lock the password of `leaver`.

## Constraints

- Do not delete the account `leaver`, the group `flight-ops` or the file `/srv/flight-ops/roster`.
- Do not change the access of `crew-member`: its group membership, its sudo rule and its RoleBinding `crew-member-view` stay as they are.

## How the answer is checked

The grader runs four checks. The first check confirms that `leaver` is not in `flight-ops` and that a read of the roster as `leaver` fails. The second check searches `/etc/sudoers.d` and `/etc/sudoers` for the word `leaver` and runs `visudo -c` if the node has it. The third check lists all RoleBindings and ClusterRoleBindings and asks the API server whether `leaver` can create Deployments, list Pods or list nodes. The fourth check expects the status `L` from `passwd -S leaver`. Every check also confirms that `crew-member` can still read the roster, keeps its sudo rule and can still list Pods in `starfleet-033-020-01-03`.
