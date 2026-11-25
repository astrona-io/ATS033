#!/usr/bin/env bash
# Reference solution: label the first worker, move ledger onto it, then taint
# the worker so that other pods stay away.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-010-03-03}"
worker_name="$cluster-worker"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl label node "$worker_name" node-restriction.kubernetes.io/dedicated=ledger --overwrite
kubectl apply -f "$lab_directory/solution/deployment-ledger.yaml"
kubectl -n starfleet-033-010-03-03 rollout status deployment/ledger --timeout=180s
kubectl taint nodes "$worker_name" dedicated=ledger:NoSchedule --overwrite
