#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-010-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-033-lab-010-03-01-control-plane"
worker_name="astro-ats-033-lab-010-03-01-worker"
kubectl apply -f "$solution_directory/deployment-beacon.yaml"
kubectl -n starfleet rollout status deployment/beacon --timeout=120s
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl apply -f "$solution_directory/configmap-workload-review.yaml"
