#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-030-01-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-033-lab-030-01-01-control-plane"
worker_name="astro-ats-033-lab-030-01-01-worker"

kubectl apply -f "$solution_directory/pod-node-local-server.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
