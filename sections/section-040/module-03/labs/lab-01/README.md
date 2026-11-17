---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Switch An AppArmor Profile From Complain To Enforce Mode

The learner finds that the profile `k8s-deny-etc-write` is loaded in complain mode on both nodes of a two-node kind cluster, reloads the same file in enforce mode with `apparmor_parser -r`, and restarts the Deployment `scout` that uses it.

The bootstrap gates on AppArmor before it changes anything. On every node, `/sys/module/apparmor/parameters/enabled` must be `Y`; otherwise it stops with `this lab needs a host with AppArmor, for example an Ubuntu Linux machine`. When a node has no `apparmor_parser`, the bootstrap installs the `apparmor` package with `apt-get` (bounded by `timeout 300`, needs internet access). When `securityfs` is not mounted, it mounts it. After either change it restarts containerd and the kubelet in that node and waits for the nodes to be ready. Then it copies `bootstrap/profiles/k8s-deny-etc-write` to both nodes, loads it with `-C`, and applies the Deployment.

The profile is an allow list: it allows reading and running every file and writing only under `/dev`, `/proc`, `/run`, `/tmp` and `/var`. It has no explicit `deny` rule, so the difference between complain and enforce mode is visible for a write under `/etc`.

A guard runs before both outcomes: `scout` keeps its container, image, command and one replica, the rollout is complete with exactly one pod, and the pod uses the `Localhost` profile `k8s-deny-etc-write`.

Outcomes (1 point each):

- `profile-enforced-on-every-node`: `/sys/kernel/security/apparmor/profiles` lists `k8s-deny-etc-write (enforce)` on both nodes.
- `scout-etc-write-denied`: `/proc/1/attr/current` in the pod reads `k8s-deny-etc-write (enforce)`, and `touch /etc/scout-check` fails with `Permission denied`.

Runtime status: pending, needs an AppArmor host. On 2026-11-17 the lab ran on a Podman machine on Apple silicon (kind v1.35.0 node image, containerd 2.2.0). That kernel has no AppArmor, so `astrona test` stopped in the bootstrap with `Stopping: this lab needs a host with AppArmor, for example an Ubuntu Linux machine (AppArmor is not enabled in the kernel of astro-test-ats-033-lab-040-03-01-control-plane)`. For this reason `solution.md` describes the expected results in prose and quotes no command output. The outcomes, the allow-list profile (whether the busybox container starts in enforce mode), the `apt-get` install, the `securityfs` mount and the restart of containerd and the kubelet still need a live run on an Ubuntu host.
