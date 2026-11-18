#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-030-03-03"
source "$lab_directory/bootstrap/helpers.sh"
run_on_worker sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
run_on_worker sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
run_on_worker systemctl restart kubelet
wait_for_worker
