#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"

# The command of a running pod cannot change, so the pod is replaced.
kubectl -n starfleet-033-030-01-01 delete pod node-local-server --wait=true
kubectl apply -f "$lab_directory/solution/pod-node-local-server.yaml"
kubectl -n starfleet-033-030-01-01 wait --for=condition=Ready pod/node-local-server --timeout=180s
