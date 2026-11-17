#!/usr/bin/env bash
# Reference solution: replace the beacon Deployment with the hardened version.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/solution/deployment-beacon.yaml"
kubectl -n starfleet-033-010-03-01 rollout status deployment/beacon --timeout=180s
