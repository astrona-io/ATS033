---
exam_objectives:
- Minimize external access to the network
---
# Remove Anonymous Access From RBAC Bindings

The bootstrap creates the namespace `starfleet-033-030-03-02`, the ServiceAccount `shuttle`, the ClusterRole and ClusterRoleBinding `namespace-reader` (subjects: group `ops-team` and user `system:anonymous`), and the Role and RoleBinding `pod-reader` (subjects: ServiceAccount `shuttle` and group `system:unauthenticated`). The API server keeps its default `--anonymous-auth` setting. The learner removes only the anonymous subjects.

Outcomes (1 point each):

- `anonymous-namespace-list-denied`: an anonymous `curl` from the control-plane node to `/api/v1/namespaces` gets `401` or `403`, and no ClusterRoleBinding except `system:public-info-viewer` names `system:anonymous` or `system:unauthenticated`.
- `unauthenticated-pod-read-denied`: an anonymous `curl` to `/api/v1/namespaces/starfleet-033-030-03-02/pods` gets `401` or `403`, and no RoleBinding in that namespace names `system:anonymous` or `system:unauthenticated`.

Guards: anonymous `/healthz` returns `200`; `kubectl auth can-i` returns `yes` for the group `ops-team` (list namespaces) and for the ServiceAccount `shuttle` (list pods).

The checks read bindings instead of using `kubectl auth can-i --as=system:anonymous`, because that command fails with `Forbidden` on the SelfSubjectAccessReview for the anonymous user.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): on the start state both anonymous list requests returned `200`; after the two bindings were applied they returned `403`, `/healthz` stayed `ok`, `ops-team` and `shuttle` kept `yes`, and both outcomes passed.
