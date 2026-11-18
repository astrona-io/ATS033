#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Seed two accounts, one group and a world-readable log file on the node.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-020-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-020-01-01"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-020-01-01"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node sh -c 'getent group flight-log-readers >/dev/null || groupadd flight-log-readers'
for account in navigator cadet; do
  run_on_node sh -c "id $account >/dev/null 2>&1 || useradd --user-group --create-home --shell /bin/bash $account"
done
run_on_node mkdir -p /srv/flight-logs
run_on_node sh -c 'printf "orbit=stable fuel=82\n" > /srv/flight-logs/telemetry.log'
run_on_node chown root:root /srv/flight-logs/telemetry.log
run_on_node chmod 0644 /srv/flight-logs/telemetry.log
