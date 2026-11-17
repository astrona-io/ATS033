#!/usr/bin/env bash
# Seed two host accounts, one group and a world-readable log file on the
# control-plane node container of this lab.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-020-01-01}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing a node container outside this lab\n' >&2
  exit 1
fi
run_on_node() { "$engine" exec "$node_name" "$@"; }

run_on_node sh -c 'getent group flight-log-readers >/dev/null || groupadd flight-log-readers'
for account in navigator cadet; do
  run_on_node sh -c "id $account >/dev/null 2>&1 || useradd --user-group --create-home --shell /bin/bash $account"
done
run_on_node mkdir -p /srv/flight-logs
run_on_node sh -c 'printf "orbit=stable fuel=82\n" > /srv/flight-logs/telemetry.log'
run_on_node chown root:root /srv/flight-logs/telemetry.log
run_on_node chmod 0644 /srv/flight-logs/telemetry.log
