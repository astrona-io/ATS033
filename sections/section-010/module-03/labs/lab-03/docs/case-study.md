---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The cluster has one control-plane node and two worker nodes, `astro-ats-033-lab-010-03-03-worker` and `astro-ats-033-lab-010-03-03-worker2`. The `starfleet-033-010-03-03` namespace runs the `ledger` Deployment with two replicas. Its pod template has no `nodeSelector`, affinity or toleration, so the scheduler places the pods on any worker node. No worker node has a custom label or taint.
