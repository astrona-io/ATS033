---
draft: true
---
# Enforce A Host Firewall Boundary

Solve this question on: `terminal`

Connect with `astrona ssh ats-033-lab-030-01-02`. The VM runs HTTP services on ports 8080 and 8081. Two network namespaces represent remote clients: `trusted` uses `192.0.2.2`, and `untrusted` uses `198.51.100.2`. Their host-facing interfaces are `lab-trusted` (`192.0.2.1`) and `lab-untrusted` (`198.51.100.1`). Both services initially accept both clients.

Allow about 10 minutes for the tasks. VM startup adds time.

## Tasks

1. Use nftables on the host to reject TCP port 8080 from the untrusted peer while preserving trusted access.
2. Keep port 8081 reachable from both peers. Test both services from both client namespaces and inspect the active firewall rules.

## Constraints

Use the supplied `inet training` table and its input chain. Preserve service processes, addresses, routes, network namespaces, ICMP reachability and the VM's management access. Do not change the HTTP applications or test tools. Persistence across a VM reboot is outside this task.

## How the answer is checked

The grader makes fresh HTTP requests from both network namespaces and from host loopback. It also checks peer connectivity. Disabling a listener or breaking an interface cannot satisfy the boundary.
