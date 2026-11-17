#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace=starfleet-033-030-01-03
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
for pod in beacon shuttle; do
  kubectl -n "$namespace" wait --for=condition=Ready "pod/$pod" --timeout=180s
done
kubectl -n outpost-033-030-01-03 wait --for=condition=Ready pod/drifter --timeout=180s

# Check that the network plugin enforces NetworkPolicy before the learner relies on it.
beacon_ip="$(kubectl -n "$namespace" get pod beacon -o jsonpath='{.status.podIP}')"
request_beacon() {
  kubectl -n outpost-033-030-01-03 exec drifter -- wget -q -T 3 -O- "http://$beacon_ip:8080/"
}
request_beacon >/dev/null
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: bootstrap-enforcement-check
  namespace: $namespace
spec:
  podSelector:
    matchLabels:
      app: beacon
  policyTypes:
  - Ingress
EOF
blocked=false
for attempt in 1 2 3 4 5; do
  if ! request_beacon >/dev/null 2>&1; then
    blocked=true
    break
  fi
  sleep 2
done
kubectl -n "$namespace" delete networkpolicy bootstrap-enforcement-check --wait=true
if [[ "$blocked" != true ]]; then
  printf 'The network plugin of this cluster does not enforce NetworkPolicy\n' >&2
  exit 1
fi
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if request_beacon >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done
printf 'beacon did not answer again after the check policy was removed\n' >&2
exit 1
