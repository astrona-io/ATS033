#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Seed a leaver with access on four layers (a group, a sudoers rule, an SSH
# key and Kubernetes bindings) and a colleague, crew-member, whose access
# must stay.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-020-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-020-01-03"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-020-01-03"
source "$lab_directory/bootstrap/helpers.sh"
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
run_on_node sh -c 'printf "leaver ALL=(root) NOPASSWD: /usr/bin/systemctl restart kubelet.service\n" > /etc/sudoers.d/leaver'
run_on_node sh -c 'printf "crew-member ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet\n" > /etc/sudoers.d/crew-member'
run_on_node chmod 0440 /etc/sudoers.d/leaver /etc/sudoers.d/crew-member
run_on_node visudo -c
# The SSH key pair of leaver. The grader keeps the private key in a root-only
# directory and logs in with it to prove that key logins are refused.
key_directory=/var/lib/astrona-lab-033-020-01-03
run_on_node install -d -m 0700 "$key_directory"
run_on_node rm -f "$key_directory/leaver_ed25519" "$key_directory/leaver_ed25519.pub"
run_on_node ssh-keygen -q -t ed25519 -N '' -C leaver@laptop -f "$key_directory/leaver_ed25519"
run_on_node install -d -m 0700 -o leaver -g leaver /home/leaver/.ssh
run_on_node install -m 0600 -o leaver -g leaver "$key_directory/leaver_ed25519.pub" /home/leaver/.ssh/authorized_keys
