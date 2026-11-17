---
exam_objectives:
- Using least-privilege identity and access management
---
# Revoke A Leaver's Access Everywhere Solution

Select the private cluster and define a small helper. The helper `run_on_node` runs one command inside the control-plane node container, so every node command below changes only this lab's node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-03" || exit 1
node_name="astro-ats-033-lab-020-01-03-control-plane"
run_on_node() { podman exec "$node_name" "$@"; }
```

## 1. Find every place that grants access

A person can keep access through several separate systems. The Linux kernel checks group membership for files, sudo reads its rules from `/etc/sudoers` and `/etc/sudoers.d`, and the Kubernetes API server checks RBAC (role-based access control) bindings. Check each one.

```sh
run_on_node id leaver
run_on_node getent group flight-ops
run_on_node runuser -u leaver -- cat /srv/flight-ops/roster
run_on_node grep -rw leaver /etc/sudoers.d
```

```text
uid=1004(leaver) gid=1006(leaver) groups=1006(leaver),1005(flight-ops)
flight-ops:x:1005:leaver,crew-member
shift=night lead=crew-member
/etc/sudoers.d/leaver:leaver ALL=(root) NOPASSWD: /usr/bin/systemctl restart kubelet.service
```

`leaver` is in `flight-ops`, reads the roster and has a sudo rule in its own file. This node image has no `sudo` program, but the rule file is still the configuration that sudo would use. Next, list the RBAC bindings. The `-o wide` output adds the USERS column. The output below is shortened to the lines for this lab's users:

```sh
kubectl get rolebindings -A -o wide
kubectl get clusterrolebindings -o wide
```

```text
NAMESPACE                 NAME                 ROLE                  AGE    USERS
starfleet-033-020-01-03   crew-member-view     ClusterRole/view      67s    crew-member
starfleet-033-020-01-03   leaver-edit          ClusterRole/edit      67s    leaver
NAME                 ROLE                                    AGE    USERS
leaver-node-reader   ClusterRole/node-reader-033-020-01-03   67s    leaver
```

`leaver` has the RoleBinding `leaver-edit` in one namespace and the ClusterRoleBinding `leaver-node-reader` for the whole cluster. `kubectl auth can-i --as` asks the API server what that user may do:

```sh
kubectl auth can-i create deployments --as=leaver -n starfleet-033-020-01-03
kubectl auth can-i list nodes --as=leaver
```

```text
yes
Warning: resource 'nodes' is not namespace scoped

yes
```

## 2. Remove the group membership

`gpasswd --delete` removes one member from one group and leaves the other groups alone.

```sh
run_on_node gpasswd --delete leaver flight-ops
run_on_node id leaver
run_on_node runuser -u leaver -- cat /srv/flight-ops/roster
run_on_node runuser -u crew-member -- cat /srv/flight-ops/roster
```

```text
Removing user leaver from group flight-ops
uid=1004(leaver) gid=1006(leaver) groups=1006(leaver)
cat: /srv/flight-ops/roster: Permission denied
shift=night lead=crew-member
```

`leaver` is denied, and `crew-member` still reads the roster.

## 3. Remove the sudo rule

The rule for `leaver` is the only line in `/etc/sudoers.d/leaver`, so delete the file. If a rule shared a file with other rules, you would delete only that line and check the file with `visudo -c`.

```sh
run_on_node rm /etc/sudoers.d/leaver
run_on_node ls -l /etc/sudoers.d
run_on_node grep -rw leaver /etc/sudoers.d
```

```text
total 4
-r--r-----. 1 root root 68 Nov 17 21:46 crew-member
```

The last `grep` prints nothing and exits with code 1, so no rule names `leaver`. The rule for `crew-member` stays.

## 4. Delete the RBAC bindings

The API server does not know Linux accounts. It only matches the user name in the request against the subjects of each binding, so the bindings must go too.

```sh
kubectl -n starfleet-033-020-01-03 delete rolebinding leaver-edit
kubectl delete clusterrolebinding leaver-node-reader
```

```text
rolebinding.rbac.authorization.k8s.io "leaver-edit" deleted from starfleet-033-020-01-03 namespace
clusterrolebinding.rbac.authorization.k8s.io "leaver-node-reader" deleted
```

Then check the result:

```sh
kubectl auth can-i create deployments --as=leaver -n starfleet-033-020-01-03
kubectl auth can-i list pods --as=leaver -n starfleet-033-020-01-03
kubectl auth can-i list nodes --as=leaver
kubectl auth can-i list pods --as=crew-member -n starfleet-033-020-01-03
```

```text
no
no
Warning: resource 'nodes' is not namespace scoped

no
yes
```

`leaver` has no access left, and `crew-member` still lists Pods through `crew-member-view`. The ClusterRole `node-reader-033-020-01-03` stays, because a ClusterRole grants nothing without a binding.

## 5. Lock the password

```sh
run_on_node usermod --lock leaver
run_on_node passwd -S leaver
```

```text
leaver L 2026-11-17 0 99999 7 -1
```

The status `L` shows a locked password. Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-01-03`.

## Common pitfalls

> [!WARNING]
> - **Fixing one system only.** Locking the Linux account does not touch Kubernetes RBAC, and deleting a binding does not touch the node. Check each system.
> - **Missing the ClusterRoleBinding.** `kubectl get rolebindings -A` does not list ClusterRoleBindings. Run both commands.
> - **Breaking sudoers.** A syntax error in any file under `/etc/sudoers.d` can stop sudo for everyone. Delete whole files when you can, and run `visudo -c` when the node has it.
> - **Removing the wrong member.** `usermod --groups` without `--append` replaces the whole list. `gpasswd --delete` changes one membership only.
