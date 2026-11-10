#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-capstone-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-010-capstone-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
python3 "$solution_directory/disable-service.py"
python3 "$solution_directory/harden-ssh.py"
kubectl apply -f "$solution_directory/deployment-beacon.yaml"
kubectl -n starfleet rollout status deployment/beacon --timeout=120s
kubectl label node "$worker_name" node-restriction.kubernetes.io/dedicated=ledger --overwrite
kubectl apply -f "$solution_directory/deployment-ledger.yaml"
kubectl -n starfleet rollout status deployment/ledger --timeout=120s
kubectl taint nodes "$worker_name" dedicated=ledger:NoSchedule --overwrite
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl apply -f "$solution_directory/configmap-section-review.yaml"
