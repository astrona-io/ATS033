---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Drop All Capabilities Except NET_BIND_SERVICE

The learner removes `privileged: true` from a root web server, blocks privilege escalation, drops all capabilities and adds back only `NET_BIND_SERVICE`, then proves the result from `/proc/1/status` and with a real request and a failing `chown`. The lab uses a single-node pinned kind cluster and seeds only the namespace and the Deployment `relay`.

A guard runs before every outcome: `relay` keeps its container, image, command and one replica, and exactly one pod is ready.

Outcomes (1 point each):

- `relay-no-escalation`: the container is not privileged and `/proc/1/status` reports `NoNewPrivs: 1`.
- `relay-capability-set`: `CapBnd` and `CapEff` are both `0000000000000400`. The process runs as root, so the effective set shows the added capability.
- `relay-still-serves`: `wget` inside the pod reads `relay-ok` from port 80, and `chown 1000 /www/index.html` fails with exit code 1 and `Operation not permitted`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

Live run on 2026-11-17 (kind v1.35.0 node image, Podman machine on Apple silicon, containerd 2.2.0): on the start state, `relay-capability-set` failed with `found 000001ffffffffff`, `relay-no-escalation` failed with `The relay container must not be privileged`, and `relay-still-serves` failed because `chown` worked. The commands in `solution.md` produced the output quoted there, and `astrona test` passed.

In this kind cluster, `net.ipv4.ip_unprivileged_port_start` reads `0` inside the pod network namespace (containerd sets it), so a non-root user could bind port 80 even without the capability. That is why the task keeps the process as root: for root, `CapEff` shows exactly which capabilities the process holds, and the `chown` check proves that `CHOWN` is gone.
