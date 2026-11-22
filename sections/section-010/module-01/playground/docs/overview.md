---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Guided Practice: Disable An Unneeded Node Service

This playground is one Ubuntu 24.04 virtual machine (VM). kubeadm installed Kubernetes v1.35.10 on it as a single node, so the same machine runs the control plane, the kubelet and the workloads. The node runs a service named `training-extra.service` that has no purpose in the cluster. In this practice you find it, turn it off in a way that survives a reboot, and prove that the node still works.

Open a shell on the VM and confirm that `kubectl` points at this playground:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-010-01
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-playground-010-01
```

You are logged in as the `student` user. This user has a kubeconfig file, which tells `kubectl` which cluster to use and which credentials to send. Commands that change the node start with `sudo`, which runs one command as root. They change only this VM, not your own computer.

## Find the service

systemd is the first process of the node, and it starts and supervises every service. `systemctl` asks systemd about its units. Read the unit file of the service and check what depends on it:

```sh
systemctl cat training-extra.service
systemctl list-dependencies --reverse training-extra.service --no-pager
```

```text
# /etc/systemd/system/training-extra.service
[Unit]
Description=Disposable training service

[Service]
ExecStart=/bin/sleep 3600

[Install]
WantedBy=multi-user.target
training-extra.service
● └─multi-user.target
●   └─graphical.target
```

The service runs `/bin/sleep 3600`, and only the boot target `multi-user.target` wants it. No other service needs it, so it can go.

## Disable and stop it

A service has two separate states: active (running now) and enabled (started at boot). `systemctl stop` changes only the first. `systemctl disable --now` removes the boot link and stops the process in one command:

```sh
sudo systemctl disable --now training-extra.service
systemctl is-active training-extra.service
systemctl is-enabled training-extra.service
```

```text
Removed "/etc/systemd/system/multi-user.target.wants/training-extra.service".
inactive
disabled
```

The first line shows the boot link that systemd removed. `is-active` exits with a non-zero status when the answer is `inactive`, which is normal for this command.

## Verify the node

A change to a node service must not affect the kubelet or the container runtime. Check both, and ask the API server whether it is ready:

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

Both services are active, the API server answers `ok`, and the node is `Ready`. The value in the `AGE` column depends on when you run the command.

## Common pitfalls

> [!WARNING]
> - **Stopping without disabling.** `systemctl stop` leaves the service enabled, so it runs again after the next reboot.
> - **Checking only the changed service.** Also check `kubelet`, `containerd` and `/readyz`, because a change that looks local can affect the node.
> - **Deleting a unit file that a package owns.** The next package update puts it back. Use `systemctl mask` for a packaged unit.
