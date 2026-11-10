#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-020-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/role-ops-agent-reader.yaml" -f "$solution_directory/rolebinding-ops-agent-reader.yaml"
kubectl delete clusterrolebinding ops-agent-admin --ignore-not-found
kubectl -n starfleet delete rolebinding ops-wide --ignore-not-found
kubectl -n starfleet delete role ops-wide --ignore-not-found
