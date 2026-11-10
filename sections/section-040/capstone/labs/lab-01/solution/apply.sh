#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-capstone-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-capstone-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
kubectl apply -f "$solution_directory/deployment-cargo.yaml"
kubectl -n starfleet rollout status deployment/cargo --timeout=180s
