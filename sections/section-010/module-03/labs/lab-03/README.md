---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Dedicate A Worker Node To One Workload

This lab uses two worker nodes. The setup script applies the `starfleet-033-010-03-03` namespace and the `ledger` Deployment (2 replicas, no placement rules) and waits for the rollout. The learner labels and taints `astro-ats-033-lab-010-03-03-worker` and adds a `nodeSelector` and a toleration to `ledger`.

Two outcomes are graded. `worker-dedicated` needs the label `node-restriction.kubernetes.io/dedicated=ledger` and the taint `dedicated=ledger:NoSchedule` on the first worker and no such taint on `worker2`. It then creates the pod `visitor-check` with a `kubernetes.io/hostname` selector for the worker and no toleration, needs the scheduler to report `Unschedulable` within about 15 seconds, and deletes the pod. `ledger-pinned` needs a matching toleration (`Equal` with the value, or `Exists`), a `nodeSelector` or required node affinity for the label, at least 2 replicas, a complete rollout and every `ledger` pod Ready on the dedicated worker.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution (label, apply the Deployment, wait, taint) is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed with 2/2 points, and `verify-start.sh` failed both outcomes on the starting state. The commands and output in `solution.md` come from a manual run of the same environment.
