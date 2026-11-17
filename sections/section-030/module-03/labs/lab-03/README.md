---
exam_objectives:
- Minimize external access to the network
---
# Close The Kubelet API To Anonymous Callers

The bootstrap creates the namespace `starfleet-033-030-03-03` and the ServiceAccount `metrics-reader` (no RBAC permissions). It then sets `authentication.anonymous.enabled: true` and `authorization.mode: AlwaysAllow` in `/var/lib/kubelet/config.yaml` on the worker node, restarts the kubelet and waits until an anonymous `curl` to `https://127.0.0.1:10250/pods` returns `200`. The learner restores the secure settings and restarts the kubelet.

Outcomes (1 point each):

- `anonymous-auth-disabled`: the running configuration (`/api/v1/nodes/<worker>/proxy/configz`) has `authentication.anonymous.enabled: false`, and an anonymous `curl` from the worker node to the kubelet gets `401`.
- `webhook-authorization`: the running configuration has `authorization.mode: Webhook`, and a `metrics-reader` token gets `403` from the kubelet.

Guards: the worker node is Ready and the running kubelet keeps `authentication.webhook.enabled: true`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): on the start state both the anonymous request and the `metrics-reader` token got `200` with the pod list; after the change and a kubelet restart they got `401` and `403` (`Forbidden (user=system:serviceaccount:starfleet-033-030-03-03:metrics-reader, verb=get, resource=nodes, subresource(s)=[pods proxy])`), the worker stayed Ready, and both outcomes passed.
