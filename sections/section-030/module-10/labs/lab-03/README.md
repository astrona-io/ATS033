---
exam_objectives:
- Minimize external access to the network
---
# Default-Deny Ingress With One Allowed Client

The bootstrap seeds `probe` (Deployment and Service), `beacon` and `shuttle` in `starfleet-033-030-01-03`, and `drifter` in `outpost-033-030-01-03`. It then checks that the CNI plugin enforces NetworkPolicy: a temporary deny policy on `beacon` must make a request from `drifter` fail, and the request must work again after the policy is removed. The bootstrap fails with a clear message if this check fails.

Outcomes:

- `default-deny-ingress`: a NetworkPolicy with an empty `podSelector`, `Ingress` in `policyTypes` and no ingress rules exists, and requests from `shuttle` and `drifter` to the `beacon` pod IP on port 8080 time out.
- `shuttle-to-probe-only`: `shuttle` gets `version=v1` from the Service `probe`, and a request from `drifter` to the Service times out.

The CNI finding: kindnet on `kindest/node:v1.35.0` enforces NetworkPolicy, so the lab needs no extra CNI plugin.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman, kindnet): the bootstrap enforcement check passed, the start state failed both outcomes, and `astrona test` passed after the reference solution.
