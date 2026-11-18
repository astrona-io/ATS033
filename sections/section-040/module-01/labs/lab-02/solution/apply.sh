#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-040-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-040-01-02"
source "$lab_directory/bootstrap/helpers.sh"
# The VM is the only node, so its kernel is the one that needs the profile.
run_on_node cp "$lab_directory/solution/k8s-deny-tmp-write" /etc/apparmor.d/k8s-deny-tmp-write
run_on_node apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
kubectl apply -f "$lab_directory/solution/pod-scout.yaml"
kubectl -n starfleet-033-040-01-02 wait --for=condition=Ready pod/scout --timeout=180s
