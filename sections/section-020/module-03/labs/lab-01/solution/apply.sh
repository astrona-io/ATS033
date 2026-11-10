#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/serviceaccount-monitor.yaml" -f "$solution_directory/serviceaccount-default.yaml"
kubectl apply -f "$solution_directory/deployment-monitor.yaml"
kubectl -n starfleet-033-020-03-01 rollout status deployment/monitor --timeout=180s
kubectl -n starfleet-033-020-03-01 delete rolebinding default-pod-lister --ignore-not-found
kubectl -n starfleet-033-020-03-01 delete secret legacy-monitor-token --ignore-not-found
