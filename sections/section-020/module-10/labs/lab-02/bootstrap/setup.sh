#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Seed two accounts with real passwords (departed-user has left the team,
# pilot stays) and an sshd drop-in that allows root and password logins.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-020-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-020-01-02"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-020-01-02"
source "$lab_directory/bootstrap/helpers.sh"
for account in departed-user pilot; do
  run_on_node sh -c "id $account >/dev/null 2>&1 || useradd --user-group --create-home --shell /bin/bash $account"
done
# A real password hash, so both accounts start unlocked (passwd -S shows P).
run_on_node sh -c 'printf "departed-user:Leaving-Orbit-2026\npilot:Docking-Bay-2026\n" | chpasswd'
# sshd uses the first value it reads for a setting, and the drop-in files are
# read in name order before the rest of sshd_config, so 10- wins over the
# image's 50-cloud-init.conf.
run_on_node sh -c 'printf "# Temporary access for the migration team\nPermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/10-migration-access.conf'
run_on_node chmod 0644 /etc/ssh/sshd_config.d/10-migration-access.conf
run_on_node sshd -t
run_on_node systemctl reload ssh
