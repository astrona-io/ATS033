---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Close An Unneeded Listener On A Node Solution

Select the private environment and define a helper. The helper `run_on_node` runs one command on the control-plane node container, which is the same as running it in a shell on the node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-01" || exit 1
node_name="astro-ats-033-lab-010-01-01-control-plane"
worker_name="astro-ats-033-lab-010-01-01-worker"
run_on_node() { podman exec "$node_name" "$@"; }
```

## Find the process behind the port

`ss` is the socket statistics tool. The options `-t` (TCP), `-l` (listening), `-n` (numbers instead of names) and `-p` (the owning process) list every TCP socket that waits for connections, with the program that owns it:

```sh
run_on_node ss -tlnp
```

```text
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      4096       127.0.0.1:2379       0.0.0.0:*    users:(("etcd",pid=652,fd=6))
LISTEN 0      4096       127.0.0.1:2381       0.0.0.0:*    users:(("etcd",pid=652,fd=11))
LISTEN 0      4096      10.89.0.21:2380       0.0.0.0:*    users:(("etcd",pid=652,fd=3))
LISTEN 0      4096      10.89.0.21:2379       0.0.0.0:*    users:(("etcd",pid=652,fd=7))
LISTEN 0      4096       127.0.0.1:40535      0.0.0.0:*    users:(("containerd",pid=123,fd=14))
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=526,fd=4))
LISTEN 0      4096       127.0.0.1:10259      0.0.0.0:*    users:(("kube-scheduler",pid=534,fd=4))
LISTEN 0      4096       127.0.0.1:10248      0.0.0.0:*    users:(("kubelet",pid=712,fd=20))
LISTEN 0      4096       127.0.0.1:10249      0.0.0.0:*    users:(("kube-proxy",pid=877,fd=11))
LISTEN 0      5            0.0.0.0:8099       0.0.0.0:*    users:(("python3",pid=1637,fd=3))
LISTEN 0      4096               *:10256            *:*    users:(("kube-proxy",pid=877,fd=10))
LISTEN 0      4096               *:10250            *:*    users:(("kubelet",pid=712,fd=11))
LISTEN 0      4096               *:6443             *:*    users:(("kube-apiserver",pid=589,fd=4))
```

Every other line belongs to a Kubernetes component: `etcd`, the API server on port 6443, the kubelet on port 10250 and its local ports, the scheduler, the controller manager, `kube-proxy` and `containerd`. The line for port `8099` shows a `python3` process that listens on `0.0.0.0`, which means every IPv4 address of the node. Your process id (`pid`) will be a different number.

## Find the service that started it

`systemctl status` accepts a process id as well as a unit name, and it prints the unit that owns the process. Use the `pid` from your own `ss` output:

```sh
run_on_node systemctl status 1637 --no-pager
```

```text
● remote-diag.service - Remote diagnostics web console
     Loaded: loaded (/lib/systemd/system/remote-diag.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-11-17 21:45:34 UTC; 33s ago
   Main PID: 1637 (python3)
      Tasks: 1 (limit: 26765)
     Memory: 18.1M
        CPU: 63ms
     CGroup: /system.slice/remote-diag.service
             └─1637 /usr/bin/python3 -m http.server 8099 --bind 0.0.0.0 --directory /usr/share/doc

Nov 17 21:45:34 astro-ats-033-lab-010-01-01-control-plane systemd[1]: Started remote-diag.service - Remote diagnostics web console.
```

The unit is `remote-diag.service`. The `Loaded:` line says that it is `enabled`, so systemd starts it at boot, and the `Active:` line says that it runs now. The command line shows a Python web server that serves the directory `/usr/share/doc` to anyone who can reach the node. Before you remove a service, read its unit file and check that no other unit needs it:

```sh
run_on_node systemctl cat remote-diag.service
run_on_node systemctl list-dependencies --reverse remote-diag.service --no-pager
```

```text
# /lib/systemd/system/remote-diag.service
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
run_on_node systemctl disable --now remote-diag.service
```

```text
Removed "/etc/systemd/system/multi-user.target.wants/remote-diag.service".
```

The unit file lives in `/lib/systemd/system`, the directory that packages use. A package update could enable such a unit again, so masking it as well records the decision in `/etc/systemd/system`, where updates do not overwrite it. A masked unit cannot be started by anyone, not even as a dependency of another unit:

```sh
run_on_node systemctl mask remote-diag.service
```

```text
Created symlink /etc/systemd/system/remote-diag.service → /dev/null.
```

Disabling alone is enough for the grader. Masking is the stronger choice for a unit that a package ships.

## Verify the result

Check the service, the port and the node services that Kubernetes needs:

```sh
run_on_node systemctl is-active remote-diag.service
run_on_node systemctl is-enabled remote-diag.service
run_on_node ss -tln 'sport = :8099'
run_on_node systemctl is-active kubelet.service containerd.service
podman exec "$worker_name" systemctl is-active kubelet.service containerd.service
kubectl get --raw=/readyz
kubectl get nodes
```

```text
inactive
masked
State Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
active
active
active
active
ok
NAME                                        STATUS   ROLES           AGE   VERSION
astro-ats-033-lab-010-01-01-control-plane   Ready    control-plane   75s   v1.35.0
astro-ats-033-lab-010-01-01-worker          Ready    <none>          64s   v1.35.0
```

The service is `inactive` and `masked`. The `ss` filter `sport = :8099` keeps only sockets on port 8099, and the output has a header and no socket line, so nothing listens on the port. `kubelet` and `containerd` are `active` on both nodes, the API server answers `ok` and both nodes are `Ready`. Then submit.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-010-01-01`.

## Common pitfalls

> [!WARNING]
> - **Killing the process.** The unit has `Restart=always`, so systemd starts the program again. Change the service with `systemctl`, not the process.
> - **Stopping without disabling.** `systemctl stop` leaves the service enabled, and it starts again at the next boot.
> - **Deleting the unit file without `systemctl daemon-reload`.** systemd keeps the old definition in memory until it reads the unit files again.
