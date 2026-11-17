---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Set An AppArmor Profile For One Container

The learner finds that a pod-level `appArmorProfile` (`Localhost` `k8s-deny-tmp-write`) makes the `console` container of the pod `bridge` crash, because it cannot write under `/tmp`. The learner creates the pod again with the pod-level type `RuntimeDefault` and gives only the `logger` container the `Localhost` profile. The pod must be created again, because its security context cannot change.

The bootstrap gates on AppArmor before it changes anything. On every node, `/sys/module/apparmor/parameters/enabled` must be `Y`; otherwise it stops with `this lab needs a host with AppArmor, for example an Ubuntu Linux machine`. When a node has no `apparmor_parser`, the bootstrap installs the `apparmor` package with `apt-get` (bounded by `timeout 300`, needs internet access). When `securityfs` is not mounted, it mounts it. After either change it restarts containerd and the kubelet in that node and waits for the nodes to be ready. Then it copies `bootstrap/profiles/k8s-deny-tmp-write` to both nodes, loads it in enforce mode, applies the pod and waits, with a limit, until `console` has restarted once.

A guard runs before both outcomes: `bridge` keeps its containers, images, commands and restart policy, is ready, has the pod-level type `RuntimeDefault`, `console` uses `RuntimeDefault` and `logger` uses `Localhost` `k8s-deny-tmp-write`.

Outcomes (1 point each):

- `console-tmp-write-works`: `/proc/1/attr/current` in `console` shows a profile in enforce mode other than `k8s-deny-tmp-write`, and `touch /tmp/console-check` works.
- `logger-tmp-write-denied`: `/proc/1/attr/current` in `logger` reads `k8s-deny-tmp-write (enforce)`, and `touch /tmp/logger-check` fails with `Permission denied`.

Runtime status: pending, needs an AppArmor host. On 2026-11-17 the lab ran on a Podman machine on Apple silicon (kind v1.35.0 node image, containerd 2.2.0). That kernel has no AppArmor, so `astrona test` stopped in the bootstrap with `Stopping: this lab needs a host with AppArmor, for example an Ubuntu Linux machine (AppArmor is not enabled in the kernel of astro-test-ats-033-lab-040-03-02-control-plane)`. For this reason `solution.md` describes the expected results in prose and quotes no command output. The outcomes, the name of the containerd default profile (`cri-containerd.apparmor.d`), the `apt-get` install, the `securityfs` mount and the restart of containerd and the kubelet still need a live run on an Ubuntu host.
