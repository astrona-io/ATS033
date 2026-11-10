#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-010-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-playground-010-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
kubectl apply -f "$solution_directory/deployment-beacon.yaml"
kubectl -n starfleet rollout status deployment/beacon --timeout=120s
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl apply -f "$solution_directory/configmap-workload-review.yaml"
