---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Remove Privileged Mode And Keep One Capability

Remove privileged mode from a Deployment, drop all capabilities and keep only the one it needs. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence from inside the container. Python 3 is required on the grading host, and Podman is required to reach the node.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference repair passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
