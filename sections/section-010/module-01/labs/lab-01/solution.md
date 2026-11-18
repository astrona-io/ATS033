---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close An Unneeded Listener On A Node Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-01-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-01-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Find the process behind the port

`ss` is the socket statistics tool. The options `-t` (TCP), `-l` (listening), `-n` (numbers instead of names) and `-p` (the owning process) list every TCP socket that waits for connections, with the program that owns it. Only root may see the processes of other users, so run it with `sudo`:

```sh
sudo ss -tlnp
```

```text
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=1037,fd=3),("systemd",pid=1,fd=207))
LISTEN 0      4096      127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=474,fd=17))
LISTEN 0      4096       127.0.0.1:2379       0.0.0.0:*    users:(("etcd",pid=1658,fd=7))
LISTEN 0      4096       127.0.0.1:2381       0.0.0.0:*    users:(("etcd",pid=1658,fd=11))
LISTEN 0      4096       127.0.0.1:35211      0.0.0.0:*    users:(("containerd",pid=821,fd=15))
LISTEN 0      4096       127.0.0.1:10248      0.0.0.0:*    users:(("kubelet",pid=1768,fd=16))
LISTEN 0      4096       127.0.0.1:10249      0.0.0.0:*    users:(("kube-proxy",pid=1895,fd=20))
LISTEN 0      4096       127.0.0.1:10259      0.0.0.0:*    users:(("kube-scheduler",pid=1640,fd=4))
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=1649,fd=4))
LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=474,fd=15))
LISTEN 0      4096       10.0.2.15:2379       0.0.0.0:*    users:(("etcd",pid=1658,fd=6))
LISTEN 0      4096       10.0.2.15:2380       0.0.0.0:*    users:(("etcd",pid=1658,fd=3))
LISTEN 0      5            0.0.0.0:8099       0.0.0.0:*    users:(("python3",pid=2489,fd=3))
LISTEN 0      4096               *:10250            *:*    users:(("kubelet",pid=1768,fd=17))
LISTEN 0      4096            [::]:22            [::]:*    users:(("sshd",pid=1037,fd=4),("systemd",pid=1,fd=208))
LISTEN 0      4096               *:10256            *:*    users:(("kube-proxy",pid=1895,fd=10))
LISTEN 0      4096               *:6443             *:*    users:(("kube-apiserver",pid=1634,fd=4))
```

Most lines belong to a Kubernetes component: `etcd`, the API server on port 6443, the kubelet on port 10250 and its local ports, the scheduler, the controller manager, `kube-proxy` and `containerd`. The SSH daemon `sshd` listens on port 22, which is how you logged in, and `systemd-resolve` answers name lookups on the loopback addresses. The line for port `8099` shows a `python3` process that listens on `0.0.0.0`, which means every IPv4 address of the node. Your process id (`pid`) will be a different number.

## Find the service that started it

`systemctl status` accepts a process id as well as a unit name, and it prints the unit that owns the process. Use the `pid` from your own `ss` output:

```sh
systemctl status 2489 --no-pager
```

```text
● remote-diag.service - Remote diagnostics web console
     Loaded: loaded (/usr/lib/systemd/system/remote-diag.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-11-18 08:51:26 UTC; 1s ago
   Main PID: 2489 (python3)
      Tasks: 1 (limit: 4594)
     Memory: 9.2M (peak: 9.3M)
        CPU: 47ms
     CGroup: /system.slice/remote-diag.service
             └─2489 /usr/bin/python3 -m http.server 8099 --bind 0.0.0.0 --directory /usr/share/doc
```

The unit is `remote-diag.service`. The `Loaded:` line says that it is `enabled`, so systemd starts it at boot, and the `Active:` line says that it runs now. The command line shows a Python web server that serves the directory `/usr/share/doc` to anyone who can reach the node. Before you remove a service, read its unit file and check that no other unit needs it:

```sh
systemctl cat remote-diag.service
systemctl list-dependencies --reverse remote-diag.service --no-pager
```

```text
# /usr/lib/systemd/system/remote-diag.service
[Unit]
Description=Remote diagnostics web console
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8099 --bind 0.0.0.0 --directory /usr/share/doc
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
remote-diag.service
● └─multi-user.target
●   └─graphical.target
```

The line `Restart=always` explains why killing the process does not help: systemd starts a new one two seconds later. The reverse dependency list contains only the boot targets that want the service, so no other service depends on it.

## Stop the service and remove its boot start

`systemctl disable --now` removes the symbolic link that starts the service at boot, and `--now` also stops it in the same command:

```sh
sudo systemctl disable --now remote-diag.service
```

```text
Removed "/etc/systemd/system/multi-user.target.wants/remote-diag.service".
```

The unit file lives in `/usr/lib/systemd/system`, the directory that packages use. A package update could enable such a unit again, so masking it as well records the decision in `/etc/systemd/system`, where updates do not overwrite it. A masked unit cannot be started by anyone, not even as a dependency of another unit:

```sh
sudo systemctl mask remote-diag.service
```

```text
Created symlink /etc/systemd/system/remote-diag.service → /dev/null.
```

Disabling alone is enough for the grader. Masking is the stronger choice for a unit that a package ships.

## Verify the result

Check the service, the port and the node services that Kubernetes needs:

```sh
systemctl is-active remote-diag.service
systemctl is-enabled remote-diag.service
ss -tln 'sport = :8099'
systemctl is-active kubelet.service containerd.service
kubectl get --raw=/readyz; echo
kubectl get nodes
```

```text
inactive
masked
State Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
active
active
ok
NAME                          STATUS   ROLES           AGE   VERSION
astro-ats-033-lab-010-01-01   Ready    control-plane   52s   v1.35.10
```

The service is `inactive` and `masked`. The `ss` filter `sport = :8099` keeps only sockets on port 8099, and the output has a header and no socket line, so nothing listens on the port. `kubelet` and `containerd` are `active`, the API server answers `ok` and the node is `Ready`. The `/readyz` endpoint prints `ok` without a line break, so the `echo` adds one. Then submit.

## Common pitfalls

> [!WARNING]
> - **Killing the process.** The unit has `Restart=always`, so systemd starts the program again. Change the service with `systemctl`, not the process.
> - **Stopping without disabling.** `systemctl stop` leaves the service enabled, and it starts again at the next boot.
> - **Deleting the unit file without `systemctl daemon-reload`.** systemd keeps the old definition in memory until it reads the unit files again.
