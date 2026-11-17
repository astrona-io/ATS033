---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Load An AppArmor Profile And Attach It To A Pod

The learner writes the AppArmor profile `k8s-deny-tmp-write`, loads it in enforce mode on both nodes of a two-node kind cluster, and creates the pod `scout` with `appArmorProfile` type `Localhost`. The lab seeds only the namespace.

The bootstrap gates on AppArmor before it changes anything. On every node, `/sys/module/apparmor/parameters/enabled` must be `Y`; otherwise it stops with `this lab needs a host with AppArmor, for example an Ubuntu Linux machine`. When a node has no `apparmor_parser`, the bootstrap installs the `apparmor` package with `apt-get` (bounded by `timeout 300`, needs internet access). When `securityfs` is not mounted, it mounts it. After either change it restarts containerd and the kubelet in that node, because both detect AppArmor when they start, and waits for the nodes to be ready.

A guard runs before every outcome: `scout` keeps its container, image, command and restart policy, is running and ready, and has the effective profile `Localhost` `k8s-deny-tmp-write`.

Outcomes (1 point each):

- `profile-loaded-on-every-node`: `/sys/kernel/security/apparmor/profiles` lists `k8s-deny-tmp-write (enforce)` on the control-plane node and on the worker node.
- `scout-confined`: `/proc/1/attr/current` in `scout` reads `k8s-deny-tmp-write (enforce)`.
- `scout-tmp-write-denied`: `touch /tmp/scout-check` in `scout` fails with `Permission denied`.

Runtime status: pending, needs an AppArmor host. On 2026-11-17 the lab ran on a Podman machine on Apple silicon (kind v1.35.0 node image, containerd 2.2.0). That kernel has no AppArmor, so `astrona test` stopped in the bootstrap with `Stopping: this lab needs a host with AppArmor, for example an Ubuntu Linux machine (AppArmor is not enabled in the kernel of astro-test-ats-033-lab-040-01-02-control-plane)`. For this reason `solution.md` describes the expected results in prose and quotes no command output. The outcomes, the `apt-get` install, the `securityfs` mount and the restart of containerd and the kubelet still need a live run on an Ubuntu host.
