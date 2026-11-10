#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-033-010-02-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-033-010-02-01 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-033-010-02-01 wait --for=condition=Ready pod/drifter --timeout=120s
python3 "$lab_directory/bootstrap/seed-ssh.py"
