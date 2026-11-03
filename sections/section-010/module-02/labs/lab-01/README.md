---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Harden SSH Access And Unused Accounts

Make key-only SSH access for one administrator account on a node and remove login paths of an unused account.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
