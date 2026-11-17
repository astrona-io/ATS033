---
exam_objectives:
- Minimize external access to the network
---
# Close An Accidental NodePort

The bootstrap seeds the Deployment `probe`, the ClusterIP Service `probe`, the NodePort Service `probe-debug` on node port 30080, `shuttle` in `starfleet-033-030-02-01` and `drifter` in `outpost-033-030-02-01`. The learner changes `probe-debug` to type `ClusterIP`.

Outcomes:

- `debug-cluster-ip`: `probe-debug` has type `ClusterIP` and no `nodePort`, and `shuttle` still gets `version=v1` through it.
- `node-port-closed`: requests from `drifter` to port 30080 on both node InternalIPs fail (`connection refused` or `timed out`).

A guard checks that the Service `probe` still answers `shuttle`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): the start state failed both outcomes, `kubectl apply` of the ClusterIP manifest removed the node port, both node addresses refused port 30080, and `astrona test` passed after the reference solution.
