#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/serviceaccount-default.yaml"
kubectl -n starfleet-033-020-03-03 delete rolebinding default-edit --ignore-not-found
kubectl -n starfleet-033-020-03-03 delete secret legacy-monitor-token --ignore-not-found
