#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-capstone-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/role-deployer.yaml" -f "$solution_directory/rolebinding-deployer.yaml"
kubectl apply -f "$solution_directory/serviceaccount-default.yaml" -f "$solution_directory/serviceaccount-reporter.yaml"
kubectl apply -f "$solution_directory/role-pod-reader.yaml" -f "$solution_directory/rolebinding-reporter-pod-reader.yaml"
kubectl apply -f "$solution_directory/deployment-reporter.yaml"
kubectl -n outpost rollout status deployment/reporter --timeout=180s
kubectl delete clusterrolebinding deployer-admin --ignore-not-found
kubectl -n outpost delete rolebinding default-edit --ignore-not-found
kubectl -n outpost delete secret legacy-deployer-token --ignore-not-found
