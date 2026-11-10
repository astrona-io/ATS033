#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-030-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-playground-030-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

sed "s/astro-ats-033-playground-030-01-control-plane/$cluster-control-plane/" "$solution_directory/pod-node-local-server.yaml" | kubectl apply -f -
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
