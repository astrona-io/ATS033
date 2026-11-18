#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-040-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
# The security context of a pod cannot change, so the pod is created again.
kubectl -n starfleet-033-040-03-02 delete pod bridge --ignore-not-found --wait=true --timeout=120s
kubectl apply -f "$solution_directory/pod-bridge.yaml"
kubectl -n starfleet-033-040-03-02 wait --for=condition=Ready pod/bridge --timeout=180s
