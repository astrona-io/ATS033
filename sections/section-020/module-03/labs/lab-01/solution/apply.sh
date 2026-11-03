#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-020-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/serviceaccount-monitor.yaml" -f "$solution_directory/serviceaccount-default.yaml"
kubectl apply -f "$solution_directory/deployment-monitor.yaml"
kubectl -n starfleet rollout status deployment/monitor --timeout=180s
kubectl -n starfleet delete rolebinding default-pod-lister --ignore-not-found
kubectl -n starfleet delete secret legacy-monitor-token --ignore-not-found
