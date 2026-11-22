---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Dedicate A Worker Node To One Workload

Allow about 10 minutes for the tasks.

Solve this question on: `terminal`

The `ledger` Deployment in the `starfleet-033-010-03-03` namespace handles payment records. Its two pods may run on either worker node today, next to any other workload. The team wants the first worker node to run `ledger` pods and to refuse every pod that does not tolerate it.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-03" || exit 1
worker_name="astro-ats-033-lab-010-03-03-worker"
```

Keep this connection selected. Every script supplied with this task refuses a different context.

The time above does not count the cluster startup.

## Tasks

1. Label the node `astro-ats-033-lab-010-03-03-worker` with `node-restriction.kubernetes.io/dedicated=ledger`.
2. Change the `ledger` Deployment so that its pods run only on nodes with that label and tolerate the taint `dedicated=ledger:NoSchedule`.
3. Taint the node `astro-ats-033-lab-010-03-03-worker` with `dedicated=ledger:NoSchedule`.

## Constraints

- Do not taint or label `astro-ats-033-lab-010-03-03-worker2` or the control-plane node.
- Keep the Deployment name, the label `app: ledger`, the image, the command and at least 2 replicas.

## How the answer is checked

The first check reads the node `astro-ats-033-lab-010-03-03-worker` and needs the label and the taint. The second worker must not carry the taint. The grader then creates a test pod with a `nodeSelector` for that node and no toleration, and the scheduler must mark it `Unschedulable`. The grader deletes the test pod afterwards. The second check needs a toleration for the taint and a `nodeSelector` (or a required node affinity) for the label in the `ledger` pod template, a complete rollout, and every `ledger` pod Ready on the dedicated worker.
