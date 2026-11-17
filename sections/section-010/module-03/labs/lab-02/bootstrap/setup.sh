#!/usr/bin/env bash
# Seeds the outpost namespace without Pod Security labels and the tracker
# Deployment, whose pod shares the process namespace of the node.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n outpost-033-010-03-02 rollout status deployment/tracker --timeout=180s
