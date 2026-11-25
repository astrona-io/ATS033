---
exam_objectives:
- Using least-privilege identity and access management
---
# Revoke A Leaver's Access Everywhere Solution

Open a shell on the lab VM. The VM is the only node of the cluster, so every command below runs on the node itself and changes only this lab.

```sh
astrona ssh astro-ats-033-lab-020-01-03
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-020-01-03
```

You are logged in as `student`. This user may run any command as `root` through `sudo`, and its kubeconfig file gives `kubectl` administrator access to the cluster.

## 1. Find every place that grants access

A person can keep access through several separate systems. The Linux kernel checks group membership for files. sudo reads its rules from `/etc/sudoers` and `/etc/sudoers.d`. The SSH daemon (sshd) accepts any key listed in `~/.ssh/authorized_keys`. The Kubernetes API server checks RBAC (role-based access control) bindings. Check each one, starting with the group and the sudo rules:

```sh
id leaver
getent group flight-ops
sudo runuser -u leaver -- cat /srv/flight-ops/roster
sudo grep -rw leaver /etc/sudoers.d
sudo -l -U leaver
```

```text
uid=1003(leaver) gid=1004(leaver) groups=1004(leaver),1003(flight-ops)
flight-ops:x:1003:leaver,crew-member
shift=night lead=crew-member
/etc/sudoers.d/leaver:leaver ALL=(root) NOPASSWD: /usr/bin/systemctl restart kubelet.service
Matching Defaults entries for leaver on astro-ats-033-lab-020-01-03:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin, use_pty

User leaver may run the following commands on astro-ats-033-lab-020-01-03:
    (root) NOPASSWD: /usr/bin/systemctl restart kubelet.service
```

`leaver` is in `flight-ops` and reads the roster. `grep` finds the rule file, and `sudo -l -U leaver` shows what sudo itself would allow: a restart of the kubelet as `root`, without a password. Next, look for an SSH key. The private key of `leaver` is kept in `/var/lib/astrona-lab-033-020-01-03/leaver_ed25519` so that you can test a real key login:

```sh
sudo cat /home/leaver/.ssh/authorized_keys
sudo ssh -i /var/lib/astrona-lab-033-020-01-03/leaver_ed25519 -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR leaver@127.0.0.1 id -un
```

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPFerC+ppuvfmRAuvHoovRB6irs7Bz2qLb+xNRFlFoo8 leaver@laptop
leaver
```

The key login works and runs `id -un` as `leaver`. Your key is different, because setup creates a new one for each lab. Last, list the RBAC bindings. The `-o wide` output adds the USERS column. kubeadm creates many system bindings, so the output below is shortened: it keeps the first five columns and only the lines for this lab's users.

```sh
kubectl get rolebindings -A -o wide
kubectl get clusterrolebindings -o wide
```

```text
NAMESPACE                 NAME                 ROLE                AGE   USERS
starfleet-033-020-01-03   crew-member-view     ClusterRole/view    10s   crew-member
starfleet-033-020-01-03   leaver-edit          ClusterRole/edit    10s   leaver
NAME                 ROLE                                    AGE   USERS
leaver-node-reader   ClusterRole/node-reader-033-020-01-03   10s   leaver
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
sudo gpasswd --delete leaver flight-ops
id leaver
sudo runuser -u leaver -- cat /srv/flight-ops/roster
sudo runuser -u crew-member -- cat /srv/flight-ops/roster
```

```text
Removing user leaver from group flight-ops
uid=1003(leaver) gid=1004(leaver) groups=1004(leaver)
cat: /srv/flight-ops/roster: Permission denied
shift=night lead=crew-member
```

`leaver` is denied, and `crew-member` still reads the roster.

## 3. Remove the sudo rule

The rule for `leaver` is the only line in `/etc/sudoers.d/leaver`, so delete the file. If a rule shared a file with other rules, you would edit that file with `visudo -f` and delete only that line. Then check every sudoers file with `visudo -c`, and ask sudo again:

```sh
sudo rm /etc/sudoers.d/leaver
sudo visudo -c
sudo -l -U leaver
sudo -l -U crew-member
```

```text
/etc/sudoers: parsed OK
/etc/sudoers.d/90-cloud-init-users: parsed OK
/etc/sudoers.d/README: parsed OK
/etc/sudoers.d/crew-member: parsed OK
User leaver is not allowed to run sudo on astro-ats-033-lab-020-01-03.
Matching Defaults entries for crew-member on astro-ats-033-lab-020-01-03:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin, use_pty

User crew-member may run the following commands on astro-ats-033-lab-020-01-03:
    (root) NOPASSWD: /usr/bin/journalctl --unit kubelet
```

Every file parses, `leaver` may run nothing with sudo, and the rule for `crew-member` stays.

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

## 5. Lock the password and remove the SSH key

`usermod --lock` puts a `!` in front of the password hash, so no password can match it. Lock the password, then test the key login again:

```sh
sudo usermod --lock leaver
sudo passwd -S leaver
sudo ssh -i /var/lib/astrona-lab-033-020-01-03/leaver_ed25519 -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR leaver@127.0.0.1 id -un
```

```text
leaver L 2026-11-18 0 99999 7 -1
leaver
```

The status is `L`, but the key login still works. sshd checks the key itself and does not use the password, so a lock does not stop it. Remove the key file and test again:

```sh
sudo rm /home/leaver/.ssh/authorized_keys
sudo ssh -i /var/lib/astrona-lab-033-020-01-03/leaver_ed25519 -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR leaver@127.0.0.1 id -un
```

```text
leaver@127.0.0.1: Permission denied (publickey).
```

sshd now refuses the key. Submit with `astrona submit`. When you are done, leave the VM with `exit` and remove the lab with `astrona destroy ats-033-lab-020-01-03`.

## Common pitfalls

> [!WARNING]
> - **Fixing one system only.** Locking the Linux account does not touch Kubernetes RBAC, and deleting a binding does not touch the node. Check each system.
> - **Trusting the lock for SSH.** A locked password does not stop a key login. Remove the key from `authorized_keys` too, or expire the account.
> - **Missing the ClusterRoleBinding.** `kubectl get rolebindings -A` does not list ClusterRoleBindings. Run both commands.
> - **Breaking sudoers.** A syntax error in any file under `/etc/sudoers.d` can stop sudo for everyone. Delete whole files when you can, edit with `visudo -f`, and run `visudo -c` after every change.
> - **Removing the wrong member.** `usermod --groups` without `--append` replaces the whole list. `gpasswd --delete` changes one membership only.
