#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-040-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-playground-040-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
kubectl apply -f "$solution_directory/pod-bind-only.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/bind-only --timeout=180s
