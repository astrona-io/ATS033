#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kubernetes-admin@astro-ats-033-playground-040-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null
