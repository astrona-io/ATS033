#!/usr/bin/env bash
# Seed a leaver with access on three layers (a group, a sudoers rule and
# Kubernetes bindings) and a colleague, crew-member, whose access must stay.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-020-01-03}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing a node container outside this lab\n' >&2
  exit 1
fi
run_on_node() { "$engine" exec "$node_name" "$@"; }
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"

kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"

run_on_node sh -c 'getent group flight-ops >/dev/null || groupadd flight-ops'
for account in leaver crew-member; do
  run_on_node sh -c "id $account >/dev/null 2>&1 || useradd --user-group --groups flight-ops --create-home --shell /bin/bash $account"
done
# Real password hashes, so both accounts start unlocked (passwd -S shows P).
run_on_node sh -c 'printf "leaver:Final-Shift-2026\ncrew-member:Night-Watch-2026\n" | chpasswd'
run_on_node mkdir -p /srv/flight-ops
run_on_node sh -c 'printf "shift=night lead=crew-member\n" > /srv/flight-ops/roster'
run_on_node chown root:flight-ops /srv/flight-ops/roster
run_on_node chmod 0640 /srv/flight-ops/roster
# The node image has no sudo package; the rule files are still real sudoers
# files that a sudo installation would read.
run_on_node mkdir -p /etc/sudoers.d
run_on_node chmod 0750 /etc/sudoers.d
run_on_node sh -c 'printf "leaver ALL=(root) NOPASSWD: /usr/bin/systemctl restart kubelet.service\n" > /etc/sudoers.d/leaver'
run_on_node sh -c 'printf "crew-member ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet\n" > /etc/sudoers.d/crew-member'
run_on_node chmod 0440 /etc/sudoers.d/leaver /etc/sudoers.d/crew-member
