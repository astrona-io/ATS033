#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# Wait (bounded) until the aggregation controller has copied the Secret rule into view.
for attempt in $(seq 1 30); do
  if kubectl get clusterrole view -o jsonpath='{.rules[*].resources}' | grep -qw secrets; then
    exit 0
  fi
  sleep 2
done
printf 'The ClusterRole view did not aggregate the Secret rule in time\n' >&2
exit 1
