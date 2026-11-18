#!/usr/bin/env bash
# Reference solution: stop the service and keep it from starting at boot.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-010-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-010-01-01"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-010-01-01"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node systemctl disable --now remote-diag.service
