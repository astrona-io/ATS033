#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-playground-040-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster_name="astro-ats-033-playground-040-03"
node_name="$cluster_name-control-plane"
kubectl apply -f "$solution_directory/pod-bind-only.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/bind-only --timeout=180s
