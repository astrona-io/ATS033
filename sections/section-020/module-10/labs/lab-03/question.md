---
exam_objectives:
- Using least-privilege identity and access management
---
# Revoke A Leaver's Access Everywhere

Allow about 12 minutes for the tasks.

Solve this question on: `terminal`

This lab runs a virtual machine (VM) with a one-node Kubernetes cluster, and the VM is the node. The account `leaver` has left the flight operations team. The person still has access in several places: membership of the node group `flight-ops`, which can read `/srv/flight-ops/roster`, a sudo rule in `/etc/sudoers.d`, Kubernetes RBAC (role-based access control) bindings for the user name `leaver`, a working password and an SSH key in `/home/leaver/.ssh/authorized_keys`. The private key of `leaver` is kept in `/var/lib/astrona-lab-033-020-01-03/leaver_ed25519`, so you can test a key login. The account `crew-member` is still on the team and must keep all of its access.

Open a shell on the lab VM and confirm the cluster:

```sh
astrona ssh astro-ats-033-lab-020-01-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-020-01-03`. You are logged in as the `student` user. Its kubeconfig file gives `kubectl` administrator access to the cluster. Node files and accounts belong to `root`, so run the commands that change them with `sudo`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Remove `leaver` from the group `flight-ops`, so that `leaver` can no longer read `/srv/flight-ops/roster`.
2. Remove every sudo rule for `leaver` from the node.
3. Delete every RoleBinding and ClusterRoleBinding that names the user `leaver`, so that `kubectl auth can-i ... --as=leaver` answers `no`.
4. Lock the password of `leaver` and make sure that an SSH key login as `leaver` is refused.

## Constraints

- Do not delete the account `leaver`, the group `flight-ops` or the file `/srv/flight-ops/roster`.
- Do not change the access of `crew-member`: its group membership, its sudo rule and its RoleBinding `crew-member-view` stay as they are.

## How the answer is checked

The grader runs four checks. The first check confirms that `leaver` is not in `flight-ops` and that a read of the roster as `leaver` fails. The second check searches `/etc/sudoers.d` and `/etc/sudoers` for the word `leaver`, runs `visudo -c` and expects `sudo -l -U leaver` to say that `leaver` may not run sudo. The third check lists all RoleBindings and ClusterRoleBindings and asks the API server whether `leaver` can create Deployments, list Pods or list nodes. The fourth check expects the status `L` from `passwd -S leaver` and makes a real SSH login to `127.0.0.1` with the private key of `leaver`, which must be refused. Every check also confirms that `crew-member` can still read the roster, keeps its sudo rule and can still list Pods in `starfleet-033-020-01-03`.
