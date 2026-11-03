---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Block File Deletion With A Localhost seccomp Profile

Write a seccomp profile, place it on the node and run a pod that cannot delete files. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence from inside the container. Python 3 is required on the grading host, and Podman is required to reach the node.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference repair passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
