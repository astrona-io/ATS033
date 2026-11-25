#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/solution/service-probe-legacy.yaml"
kubectl apply -f "$lab_directory/solution/service-beacon-debug.yaml"
kubectl -n outpost-033-030-02-03 delete pod relay --wait=true
