---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Purge An Unneeded Package From A Node Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-010-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-010-01-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and services belong to root, so commands that change the node run with `sudo`. They change only the lab VM, not your own computer.

## Find the package that owns the program

`dpkg` is the low-level Debian package tool. `dpkg -S <path>` searches the list of installed files and prints the package that owns the path:

```sh
dpkg -S /usr/sbin/debug-relay
```

```text
debug-relay: /usr/sbin/debug-relay
```

The package is `debug-relay`. `dpkg-query -W` with a format string prints chosen fields of the package record. `dpkg -L` lists every file that the package installed, and the `Conffiles` field lists the files that `dpkg` treats as configuration files:

```sh
dpkg-query -W -f='${Package} ${Version} ${Status}\n' debug-relay
dpkg -L debug-relay
dpkg-query -W -f='${Conffiles}\n' debug-relay
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

The status `install ok installed` means that the package is fully installed. It ships a program, a systemd unit and one configuration file, `/etc/debug-relay/relay.conf`. A plain remove keeps configuration files on disk, so this file is the reason the task needs a purge. The service that the package started runs now. Only root may see the processes of other users in `ss -p`, so that command needs `sudo`:

```sh
systemctl is-active debug-relay.service
sudo ss -tlnp 'sport = :7070'
```

```text
active
State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
LISTEN 0      5          127.0.0.1:7070      0.0.0.0:*    users:(("python3",pid=2518,fd=3))
```

## Check what the removal would take with it

Before you remove a package, check that no other installed package needs it. `apt-cache rdepends --installed` lists the installed packages that depend on it:

```sh
apt-cache rdepends --installed debug-relay
```

```text
debug-relay
Reverse Depends:
```

The list under `Reverse Depends:` is empty. `apt-get purge --simulate` then prints what a purge would do, without changing anything:

```sh
apt-get purge --simulate debug-relay
```

```text
NOTE: This is only a simulation!
      apt-get needs root privileges for real execution.
      Keep also in mind that locking is deactivated,
      so don't depend on the relevance to the real current situation!
Reading package lists...
Building dependency tree...
Reading state information...
The following packages will be REMOVED:
  debug-relay*
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
Purg debug-relay [1.4.2]
```

A simulation does not need root, so the command runs without `sudo` and prints the `NOTE` lines. Only `debug-relay` would go. The `*` after the name and the `Purg` line mean that its configuration files would go too.

## Purge the package

`apt-get purge` removes the package and its configuration files in one step. The package's own removal script stops and disables the service first:

```sh
sudo apt-get purge --yes debug-relay
```

```text
Reading package lists...
Building dependency tree...
Reading state information...
The following packages will be REMOVED:
  debug-relay*
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
After this operation, 0 B of additional disk space will be used.
(Reading database ... 115027 files and directories currently installed.)
Removing debug-relay (1.4.2) ...
Removed "/etc/systemd/system/multi-user.target.wants/debug-relay.service".
(Reading database ... 115025 files and directories currently installed.)
Purging configuration files for debug-relay (1.4.2) ...
```

The output is shortened. The two `Reading database` lines also print a progress counter from 5% to 100%. After the `Purging` line, `debconf` and `needrestart` print messages about the terminal and about services to restart; they report no problem. The output shows both stages: `Removing` deletes the program and the unit, and `Purging configuration files` deletes `relay.conf`.

## Verify the result

Check the package record, the files, the port and the node services that Kubernetes needs:

```sh
dpkg-query -W -f='${Status}\n' debug-relay
ls /etc/debug-relay /usr/sbin/debug-relay
ss -tln 'sport = :7070'
systemctl is-active kubelet.service containerd.service
kubectl get --raw=/readyz; echo
kubectl get nodes
```

```text
dpkg-query: no packages found matching debug-relay
ls: cannot access '/etc/debug-relay': No such file or directory
ls: cannot access '/usr/sbin/debug-relay': No such file or directory
State Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
active
active
ok
NAME                          STATUS   ROLES           AGE   VERSION
astro-ats-033-lab-010-01-02   Ready    control-plane   19s   v1.35.10
```

`dpkg` has no record of the package, the program and the configuration directory are gone, and nothing listens on port 7070. `kubelet` and `containerd` are `active`, the API server answers `ok` and the node is `Ready`. The `/readyz` endpoint prints `ok` without a line break, so the `echo` adds one. Then submit.

## Common pitfalls

> [!WARNING]
> - **`apt-get remove` instead of `purge`.** A remove leaves the configuration files, and `dpkg-query` shows the status `deinstall ok config-files`. Run `apt-get purge debug-relay` to finish the job.
> - **Deleting files by hand.** `rm /usr/sbin/debug-relay` leaves the package record, the unit and the running service. The package manager also runs the package's removal scripts, which stop the service.
> - **Removing without a simulation.** On a real node, a package can pull other packages with it. Read the `--simulate` output before you remove anything.
