#!/usr/bin/env bash
# Reference solution: fix the template first, then enforce baseline.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/solution/deployment-tracker.yaml"
kubectl -n outpost-033-010-03-02 rollout status deployment/tracker --timeout=180s
kubectl label namespace outpost-033-010-03-02 pod-security.kubernetes.io/enforce=baseline --overwrite
