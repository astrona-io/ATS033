#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-030-03-01"
source "$lab_directory/bootstrap/helpers.sh"
edit_manifest kube-scheduler 's/--bind-address=0.0.0.0/--bind-address=127.0.0.1/'
