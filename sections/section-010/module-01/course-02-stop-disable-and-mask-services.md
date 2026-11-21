---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Stop, Disable And Mask Services

An unneeded service is on your list. The obvious step is to stop it, and that step feels finished because the process disappears. At the next reboot the process comes back, because stopping a service does not change what systemd starts at boot. This part separates the three actions that change a service's state, shows which one lasts, and ends with a check that the node still does its job.

## Three actions, three different changes

systemd keeps the running state and the boot behavior of a service apart, so it has a separate command for each.

- `systemctl stop` stops the running process now. It does not change the boot behavior. After a reboot, an enabled service runs again.
- `systemctl disable` removes the boot behavior. It deletes the symbolic links that the `[Install]` section of the unit created, for example the link in `multi-user.target.wants`. It does not stop a service that is running now. The option `--now` adds the stop to the same command.
- `systemctl mask` links the unit name to `/dev/null` in `/etc/systemd/system`. A masked unit cannot be started by anything: not by a person, not at boot and not as a dependency of another unit. Masking is the strongest option and is meant for units that a package ships, because a package update can enable a disabled unit again but cannot start a masked one.

```mermaid
flowchart TB
    A["Service running and enabled"] -->|"stop"| B["Stopped, still enabled"]
    A -->|"disable --now"| C["Stopped and disabled"]
    C -->|"mask"| D["Masked: cannot start"]
    B -->|"reboot"| A
```

The diagram shows that `stop` alone returns to the running state after a reboot, while `disable --now` stays stopped and `mask` also blocks manual and dependency starts.

Two more commands matter. `systemctl daemon-reload` makes systemd read unit files again after you change one. `systemctl is-active` and `systemctl is-enabled` print one word each, which makes them good checks in scripts.

## See that stop is not enough

The playground is one Ubuntu 24.04 virtual machine (VM) that is a single Kubernetes node. It carries a seeded service, `training-extra.service`, that runs `/bin/sleep 3600` and has no purpose in the cluster. Open a shell on the VM and confirm that `kubectl` points at this playground:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-010-01
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-playground-010-01
```

You are logged in as the `student` user. Questions to systemd need no special rights, but changes to a service do, so those commands start with `sudo`, which runs one command as root. Check the state of the seeded service before you change it:

```sh
systemctl is-active training-extra.service
systemctl is-enabled training-extra.service
```

```text
active
enabled
```

The service runs now and starts at boot. Now stop the service only, and ask again:

```sh
sudo systemctl stop training-extra.service
systemctl is-active training-extra.service
systemctl is-enabled training-extra.service
```

```text
inactive
enabled
```

The `is-active` answer is now `inactive`, and `is-enabled` still answers `enabled`. The process is gone, but the node would start it again at boot. Note that `is-active` exits with a non-zero status when the answer is `inactive`. That is normal for this command and is not an error in the node.

## Disable the service so it stays off

Disable the service. `--now` also stops it if it is running, so one command covers both facts:

```sh
sudo systemctl disable --now training-extra.service
```

```text
Removed "/etc/systemd/system/multi-user.target.wants/training-extra.service".
```

The command prints a line that it removed a symbolic link from `multi-user.target.wants`. That link is the boot behavior. Check both facts again:

```sh
systemctl is-active training-extra.service
systemctl is-enabled training-extra.service
```

```text
inactive
disabled
```

The answers are `inactive` and `disabled`. The unit file `/etc/systemd/system/training-extra.service` still exists, so an administrator can start the service by hand with `systemctl start`. When the service has no purpose at all, the file itself can go too, and that is the next level of removal.

## When to mask, and when to delete the unit file

Masking fits a service that a package ships in `/usr/lib/systemd/system` or `/lib/systemd/system` and that you cannot uninstall, because other software needs the package. Masking records your decision in `/etc/systemd/system`, where updates do not overwrite it. The command is `systemctl mask --now <unit>`, and `systemctl unmask <unit>` reverses it. It needs a free name in `/etc/systemd/system`, so a unit whose own file lives there, like the seeded one, is removed by deleting the file instead.

The VM has such a packaged service. `ModemManager.service` manages mobile broadband modems, and a VM in a data center has none. Read its unit file and its reverse dependencies first:

```sh
systemctl cat ModemManager.service
systemctl list-dependencies --reverse ModemManager.service --no-pager
```

```text
# /usr/lib/systemd/system/ModemManager.service
[Unit]
Description=Modem Manager
After=polkit.service
Requires=polkit.service
ConditionVirtualization=!container

[Service]
Type=dbus
BusName=org.freedesktop.ModemManager1
ExecStart=/usr/sbin/ModemManager
StandardError=null
Restart=on-abort
CapabilityBoundingSet=CAP_SYS_ADMIN CAP_NET_ADMIN
ProtectSystem=true
ProtectHome=true
PrivateTmp=true
RestrictAddressFamilies=AF_NETLINK AF_UNIX AF_QIPCRTR
NoNewPrivileges=true
User=root

[Install]
WantedBy=multi-user.target
Alias=dbus-org.freedesktop.ModemManager1.service
ModemManager.service
● └─multi-user.target
●   └─graphical.target
```

The first line shows that the file lives in `/usr/lib/systemd/system`, so the package owns it. Only `multi-user.target` wants the service, so no other service needs it. Mask it and stop it in one command, then try to start it:

```sh
sudo systemctl mask --now ModemManager.service
systemctl is-enabled ModemManager.service
sudo systemctl start ModemManager.service
ls -l /etc/systemd/system/ModemManager.service
```

```text
Created symlink /etc/systemd/system/ModemManager.service → /dev/null.
masked
Failed to start ModemManager.service: Unit ModemManager.service is masked.
lrwxrwxrwx 1 root root 9 Nov 18 09:04 /etc/systemd/system/ModemManager.service -> /dev/null
```

systemd refuses the start, because the name in `/etc/systemd/system` points to `/dev/null` and that file takes precedence over the file in `/usr/lib/systemd/system`. The package file is still on disk, but no person, boot target or other unit can start the service.

For a unit file that you or an image builder created, delete the file, then reload systemd:

```sh
sudo rm /etc/systemd/system/training-extra.service
sudo systemctl daemon-reload
systemctl status training-extra.service --no-pager
```

```text
Unit training-extra.service could not be found.
```

Both `rm` and `daemon-reload` print nothing. After the reload, `systemctl status` reports that the unit could not be found. Only delete files you created or that belong to no package. A file that a package owns returns after the next update, so mask it instead.

## Check that the node still works

Hardening has a second half: proving that the node still does its job. The kubelet and the container runtime are services too, and a careless change can stop them. Check both, and then ask the API server whether it is ready:

```sh
systemctl is-active kubelet.service containerd.service
kubectl get --raw=/readyz; echo
kubectl get nodes
```

```text
active
active
ok
NAME                              STATUS   ROLES           AGE   VERSION
astro-ats-033-playground-010-01   Ready    control-plane   52s   v1.35.10
```

`is-active` prints one answer per unit, and both are `active`. The `/readyz` endpoint answers `ok` when the API server is ready, and `echo` only adds the missing line break. `kubectl get nodes` shows the single node with the status `Ready`. The kubelet reports that status to the API server, so a node whose kubelet stopped would change to `NotReady` after a short delay.

You now know that persistence is a separate fact from the running state, and that `disable --now` and `mask` are the two actions that last. The question still open is the software itself: its files stay on disk and still need security updates, even when no service runs it.

## Common pitfalls

> [!WARNING]
> - **Stopping a service and calling it done.** `stop` leaves the service enabled, so it runs again after a reboot. Use `disable --now`.
> - **Editing a unit file and forgetting `daemon-reload`.** systemd keeps the old definition in memory until it reads the files again.
> - **Masking a unit that other units require.** A masked unit fails every unit that depends on it with a hard dependency. Check `systemctl list-dependencies --reverse` first.
> - **Verifying only the service you changed.** Also check `kubelet`, `containerd` and `/readyz`. A change that looks local can affect the node.
