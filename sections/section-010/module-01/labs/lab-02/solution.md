---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Purge An Unneeded Package From A Node Solution

Select the private environment and define a helper. The helper `run_on_node` runs one command on the control-plane node container, which is the same as running it in a shell on the node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-01-02" || exit 1
node_name="astro-ats-033-lab-010-01-02-control-plane"
worker_name="astro-ats-033-lab-010-01-02-worker"
run_on_node() { podman exec "$node_name" "$@"; }
```

## Find the package that owns the program

`dpkg` is the low-level Debian package tool. `dpkg -S <path>` searches the list of installed files and prints the package that owns the path:

```sh
run_on_node dpkg -S /usr/sbin/debug-relay
```

```text
debug-relay: /usr/sbin/debug-relay
```

The package is `debug-relay`. `dpkg-query -W` with a format string prints chosen fields of the package record. `dpkg -L` lists every file that the package installed, and the `Conffiles` field lists the files that `dpkg` treats as configuration files:

```sh
run_on_node dpkg-query -W -f='${Package} ${Version} ${Status}\n' debug-relay
run_on_node dpkg -L debug-relay
run_on_node dpkg-query -W -f='${Conffiles}\n' debug-relay
```

```text
debug-relay 1.4.2 install ok installed
/.
/etc
/etc/debug-relay
/etc/debug-relay/relay.conf
/usr
/usr/lib
/usr/lib/systemd
/usr/lib/systemd/system
/usr/lib/systemd/system/debug-relay.service
/usr/sbin
/usr/sbin/debug-relay
 /etc/debug-relay/relay.conf 2e1fa21d2a4add1e34645072ff992fdf
```

The status `install ok installed` means that the package is fully installed. It ships a program, a systemd unit and one configuration file, `/etc/debug-relay/relay.conf`. A plain remove keeps configuration files on disk, so this file is the reason the task needs a purge. The service that the package started runs now:

```sh
run_on_node systemctl is-active debug-relay.service
run_on_node ss -tlnp 'sport = :7070'
```

```text
active
State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
LISTEN 0      5          127.0.0.1:7070      0.0.0.0:*    users:(("python3",pid=1651,fd=3))
```

## Check what the removal would take with it

Before you remove a package, check that no other installed package needs it. `apt-cache rdepends --installed` lists the installed packages that depend on it:

```sh
run_on_node apt-cache rdepends --installed debug-relay
```

```text
debug-relay
Reverse Depends:
```

The list under `Reverse Depends:` is empty. `apt-get purge --simulate` then prints what a purge would do, without changing anything:

```sh
run_on_node apt-get purge --simulate debug-relay
```

```text
Reading package lists...
Building dependency tree...
Reading state information...
The following packages will be REMOVED:
  debug-relay*
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
Purg debug-relay [1.4.2]
```

Only `debug-relay` would go. The `*` after the name and the `Purg` line mean that its configuration files would go too.

## Purge the package

`apt-get purge` removes the package and its configuration files in one step. The package's own removal script stops and disables the service first:

```sh
run_on_node apt-get purge --yes debug-relay
```

```text
Reading package lists...
Building dependency tree...
Reading state information...
The following packages will be REMOVED:
  debug-relay*
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
After this operation, 0 B of additional disk space will be used.
(Reading database ... 9637 files and directories currently installed.)
Removing debug-relay (1.4.2) ...
Removed "/etc/systemd/system/multi-user.target.wants/debug-relay.service".
(Reading database ... 9635 files and directories currently installed.)
Purging configuration files for debug-relay (1.4.2) ...
```

The two `Reading database` lines are shortened: on the terminal they also print a progress counter from 5% to 100%. The output shows both stages: `Removing` deletes the program and the unit, and `Purging configuration files` deletes `relay.conf`.

## Verify the result

Check the package record, the files, the port and the node services that Kubernetes needs:

```sh
run_on_node dpkg-query -W -f='${Status}\n' debug-relay
run_on_node ls /etc/debug-relay /usr/sbin/debug-relay
run_on_node ss -tln 'sport = :7070'
run_on_node systemctl is-active kubelet.service containerd.service
podman exec "$worker_name" systemctl is-active kubelet.service containerd.service
kubectl get --raw=/readyz
```

```text
dpkg-query: no packages found matching debug-relay
ls: cannot access '/etc/debug-relay': No such file or directory
ls: cannot access '/usr/sbin/debug-relay': No such file or directory
State Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
active
active
active
active
ok
```

`dpkg` has no record of the package, the program and the configuration directory are gone, and nothing listens on port 7070. `kubelet` and `containerd` are `active` on both nodes, and the API server answers `ok`. Then submit.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-010-01-02`.

## Common pitfalls

> [!WARNING]
> - **`apt-get remove` instead of `purge`.** A remove leaves the configuration files, and `dpkg-query` shows the status `deinstall ok config-files`. Run `apt-get purge debug-relay` to finish the job.
> - **Deleting files by hand.** `rm /usr/sbin/debug-relay` leaves the package record, the unit and the running service. The package manager also runs the package's removal scripts, which stop the service.
> - **Removing without a simulation.** On a real node, a package can pull other packages with it. Read the `--simulate` output before you remove anything.
