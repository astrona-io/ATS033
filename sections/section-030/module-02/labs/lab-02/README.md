---
exam_objectives:
- Minimize external access to the network
---
# Answer A NodePort Only On Nodes With Endpoints

The bootstrap seeds the Deployment `probe` (both replicas on the worker), the NodePort Service `probe-public` on node port 30081 with `externalTrafficPolicy: Cluster`, and `drifter` on the worker in `outpost-033-030-02-02`. The learner sets `externalTrafficPolicy: Local`.

Outcome:

- `local-traffic-policy` (2 points): `probe-public` is `NodePort` on 30081 with `externalTrafficPolicy: Local`; `drifter` gets `version=v1` from the worker InternalIP on port 30081, and the request to the control-plane InternalIP on port 30081 times out.

Guards: `drifter` and every `probe` pod run on the worker. Live tests showed why `drifter` must be on the worker: kube-proxy treats traffic from a pod on the same node as internal traffic, so a pod on the control-plane node still got an answer from the control-plane address with the policy `Local`. `loadBalancerSourceRanges` is not graded, because kind has no load balancer controller.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that the outcome fails on the starting state, then the reference solution is applied and the outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): the start state failed, and `astrona test` passed after the reference solution.
