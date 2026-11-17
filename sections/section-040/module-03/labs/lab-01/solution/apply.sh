#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-03-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-03-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
# Without -C the same file loads in enforce mode.
for node_name in "$cluster-control-plane" "$cluster-worker"; do
  "$engine" exec "$node_name" apparmor_parser -r /etc/apparmor.d/k8s-deny-etc-write
done
kubectl -n starfleet-033-040-03-01 rollout restart deployment/scout
kubectl -n starfleet-033-040-03-01 rollout status deployment/scout --timeout=180s
