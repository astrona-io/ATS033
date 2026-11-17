---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The namespace `starfleet-033-040-03-03` holds the Deployment `relay` with one replica. Its container runs as root. It writes `relay-ok` to `/www/index.html` and starts the BusyBox web server `httpd` on port 80. A readiness probe opens a TCP connection to that port.

The container has `privileged: true` and `allowPrivilegeEscalation: true`. A privileged container holds every Linux capability and can reach the devices of the node. Binding to port 80 is the only privileged operation the web server needs.

The team wants the smallest set of capabilities that keeps the page working, and it wants to see the result in the process status, not only in the manifest.
