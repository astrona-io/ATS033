---
exam_objectives:
- Minimize external access to the network
---
# Audit And Close Unapproved Service Exposure

The bootstrap seeds one approved entry (`probe-public`, NodePort 30081) and three unapproved ones: `probe-legacy` with `externalIPs: [203.0.113.10]`, the NodePort Service `beacon-debug` on 30090, and the host-network pod `relay` serving port 18080 on the worker. The learner audits the cluster and closes the three unapproved entries.

Outcomes (1 point each):

- `no-external-ips`: no Service in the cluster sets `externalIPs`; `shuttle` still gets `version=v1` from `http://probe-legacy/`, and the request to `203.0.113.10` fails.
- `single-node-port`: `starfleet-033-030-02-03/probe-public` is the only Service with a node port; the worker answers on 30081 and no longer on 30090.
- `no-host-network-listener`: no pod outside the `kube-*` namespaces uses the host network, and port 18080 on the worker refuses connections.

Guards: the Deployment `probe` and the pod `shuttle` are ready.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): the three outcomes failed on the start state; after the reference steps, `203.0.113.10` timed out, ports 30090 and 18080 were refused, port 30081 and `probe-legacy` still returned `version=v1`, and all three outcomes passed.
