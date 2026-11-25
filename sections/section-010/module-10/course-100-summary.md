# Summary

Containers share the kernel, the container runtime and the files of their node. So the host operating system is part of the security boundary of the cluster, and every extra service, package or interface on it adds attack surface.

Host hardening starts with an inventory. `systemctl list-units` shows the services that run now, and `systemctl list-unit-files` shows the services that start at boot. `ss -tlnp` shows the network listeners and the process behind each one. Each item is required, kept with an owner and a reason, or a candidate for removal.

A service has two separate states. Stopping it changes only the running state, so an enabled service returns after a reboot. `disable --now` removes the boot behavior and stops the process. `mask` blocks every start, including starts by a dependency. After any change, the kubelet, the container runtime and the readiness endpoint of the API server must still be healthy.

Packages carry code and a duty to patch it. `dpkg -S` shows which package owns a file, and the package manager never patches a file that belongs to no package. `apt-get remove --simulate` shows every package a removal would take with it, which protects you from removing a dependency of the node. A package update does not change a running process until it restarts. Manual changes on one node belong in the node image or the provisioning tool, so they survive when the node is replaced.

Some interfaces give host authority without a network port: the container runtime socket, `hostPath` volumes, host namespaces and privileged containers. The kubelet must reject anonymous callers, use `Webhook` authorization and keep the read-only port off. Pod Security Admission with the `baseline` standard rejects new pods that use `hostPath` volumes, host namespaces or privileged mode.

Key facts to remember:

- Running and enabled are different states; `disable --now` changes both.
- `mask` also blocks starts by other units and survives package updates.
- Simulate with `apt-get remove --simulate` before a removal.
- Write access to the runtime socket equals root on the node.
- The `enforce` label of Pod Security Admission affects new pods only.

<!-- astrona:playground:destroy -->
