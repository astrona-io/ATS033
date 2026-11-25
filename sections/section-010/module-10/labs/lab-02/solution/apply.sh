#!/usr/bin/env bash
# Reference solution: purge the package, which removes its program, its
# service and its configuration files.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-010-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-010-01-02"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-010-01-02"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node apt-get purge --yes debug-relay
