#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# The token controller fills the Secret with a token a moment after it exists.
for attempt in $(seq 1 30); do
  if [[ -n "$(kubectl -n starfleet-033-020-03-03 get secret legacy-monitor-token -o jsonpath='{.data.token}')" ]]; then
    exit 0
  fi
  sleep 2
done
printf 'The token controller did not fill legacy-monitor-token\n' >&2
exit 1
