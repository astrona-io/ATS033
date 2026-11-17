---
exam_objectives:
- Minimize external access to the network
---
# Bind A Host-Network Service To Loopback

The bootstrap starts `node-local-server` on the control-plane host network bound to `0.0.0.0:19090`. The learner replaces the pod so that it binds `127.0.0.1:19090`.

Outcomes:

- `loopback-listener`: `ss -tlnH 'sport = :19090'` on the control-plane node lists `127.0.0.1` and no wildcard or node address.
- `node-address-refused`: `wget` from `shuttle` to the node InternalIP on port 19090 fails with `Connection refused`.

Both outcomes also need `node-local-server` Ready on the control-plane node and `curl http://127.0.0.1:19090/` on that node to return 200. The graders do not compare the pod spec, so any command that binds loopback passes.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): the start state failed both outcomes, and `astrona test` passed after the reference solution.
