#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl delete clusterrolebinding ops-agent-admin --ignore-not-found
kubectl -n starfleet-033-020-02-02 delete rolebinding ops-wide --ignore-not-found
kubectl -n starfleet-033-020-02-02 delete role ops-wide --ignore-not-found
kubectl apply -f "$solution_directory/role-ops-agent-reader.yaml"
kubectl apply -f "$solution_directory/rolebinding-ops-agent-reader.yaml"
