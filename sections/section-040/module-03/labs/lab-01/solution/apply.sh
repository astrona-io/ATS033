#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-040-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster_name="astro-ats-033-lab-040-03-01"
node_name="$cluster_name-control-plane"
kubectl apply -f "$solution_directory/deployment-relay.yaml"
kubectl -n starfleet rollout status deployment/relay --timeout=180s
