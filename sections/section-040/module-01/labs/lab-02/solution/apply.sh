#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The pod can run on either node, so both kernels need the profile.
for node_name in "$cluster-control-plane" "$cluster-worker"; do
  "$engine" cp "$lab_directory/solution/k8s-deny-tmp-write" "$node_name:/etc/apparmor.d/k8s-deny-tmp-write"
  "$engine" exec "$node_name" apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
done
kubectl apply -f "$lab_directory/solution/pod-scout.yaml"
kubectl -n starfleet-033-040-01-02 wait --for=condition=Ready pod/scout --timeout=180s
