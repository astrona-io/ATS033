#!/usr/bin/env bash
# Seed two host accounts with real passwords on the control-plane node
# container of this lab: departed-user has left the team, pilot stays.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-020-01-02}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing a node container outside this lab\n' >&2
  exit 1
fi
run_on_node() { "$engine" exec "$node_name" "$@"; }

for account in departed-user pilot; do
  run_on_node sh -c "id $account >/dev/null 2>&1 || useradd --user-group --create-home --shell /bin/bash $account"
done
# A real password hash, so both accounts start unlocked (passwd -S shows P).
run_on_node sh -c 'printf "departed-user:Leaving-Orbit-2026\npilot:Docking-Bay-2026\n" | chpasswd'
