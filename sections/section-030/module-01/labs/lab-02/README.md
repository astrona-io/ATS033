---
exam_objectives:
- Minimize external access to the network
---
# Allow A Node Port Only From The Worker With iptables

The bootstrap starts `node-metrics-server` on the control-plane host network on `0.0.0.0:19091`, a normal pod `shuttle` on the control-plane node and a host-network pod `scout` on the worker. The learner adds two `INPUT` rules on the control-plane node: accept TCP 19091 from the worker InternalIP, then drop TCP 19091.

Outcome:

- `worker-only-access` (2 points): `wget` from `shuttle` to the control-plane InternalIP on port 19091 times out, and the same request from `scout` returns `Directory listing for /`.

Guards: the listener still shows in `ss`, `node-metrics-server` and `shuttle` run on the control-plane node, and `scout` runs on the worker. The grader tests behaviour only, so any rule set with the same effect passes. Rule persistence and `ufw` are not graded: kind nodes have no `ufw`, and a restart of the node container is outside the lab.

`shuttle` runs on the control-plane node on purpose. Live tests showed that kindnet masquerades pod traffic that leaves a node, so a pod on the worker reaches the control-plane node with the worker InternalIP as its source address and would pass the accept rule. A pod on the control-plane node keeps its pod IP.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that the outcome fails on the starting state, then the reference solution is applied and the outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman, `iptables v1.8.9 (legacy)`): the start state failed, and `astrona test` passed after the reference solution.
