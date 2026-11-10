#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-020-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-playground-020-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
python3 "$solution_directory/grant-read.py"
kubectl apply -f "$solution_directory/configmap-identity-review.yaml"
