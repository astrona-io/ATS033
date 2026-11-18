#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/role-probe-code-reader.yaml"
kubectl apply -f "$solution_directory/rolebinding-code-reviewer.yaml"
kubectl apply -f "$solution_directory/rolebinding-inspector-view.yaml"
kubectl delete clusterrolebinding inspector-view --ignore-not-found
