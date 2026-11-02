---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Summary

Containers share the kernel, the container runtime and the files of their node, so the host operating system is part of the security boundary. Host hardening starts with an inventory: the running services from `systemctl list-units`, the services that start at boot from `systemctl list-unit-files`, and the network listeners from `ss -tlnp`. Each item is required, kept with an owner and a reason, or a candidate for removal.

A service has two separate states. Stopping it changes only the running state, so an enabled service returns after a reboot. `disable --now` removes the boot behavior and stops the process, and `mask` blocks every start, including starts by dependency. After any change, the kubelet, the container runtime and the API readiness endpoint must still be healthy.

Packages carry code and a patch duty. `dpkg -S` shows which package owns a file, and a file without a package is never patched by the package manager. `apt-get remove --simulate` shows every package a removal would take with it, which protects against removing a dependency of the node. A package update does not change a running process until it restarts, and manual changes on one node belong in the node image or provisioning so they survive replacement.

Some interfaces give host authority without a network port: the container runtime socket, `hostPath` volumes, host namespaces and privileged containers. The kubelet must reject anonymous callers, use `Webhook` authorization and keep the read-only port off. Pod Security Admission with the `baseline` standard rejects new pods that use `hostPath` volumes, host namespaces or privileged mode.

Key facts:

- Running and enabled are different states; `disable --now` changes both.
- `mask` also blocks starts by other units and survives package updates.
- Simulate with `apt-get remove --simulate` before a removal.
- Write access to the runtime socket equals root on the node.
- The `enforce` label of Pod Security Admission affects new pods only.

<!-- astrona:playground:destroy -->
