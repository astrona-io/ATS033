#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Loosens the real SSH server (sshd) of the VM. The main file keeps the image
# defaults; two drop-in files, read at its Include line, allow root and password
# logins. A Match block for the backup account goes at the end of the main file.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-010-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-010-02-01"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-010-02-01"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node tee /etc/ssh/sshd_config.d/10-legacy-root.conf >/dev/null <<'LEGACY'
# Added during the first install so that root could copy files.
permitrootlogin yes
LEGACY
run_on_node tee /etc/ssh/sshd_config.d/50-cloud-init.conf >/dev/null <<'CLOUD'
PasswordAuthentication yes
CLOUD
if ! run_on_node grep -q '^Match User backup' /etc/ssh/sshd_config; then
  run_on_node tee -a /etc/ssh/sshd_config >/dev/null <<'MATCH'

Match User backup
    # The backup account may only copy files.
    ForceCommand internal-sftp
    AllowTcpForwarding no
MATCH
fi
if ! id opsadmin >/dev/null 2>&1; then
  run_on_node useradd --create-home --shell /bin/bash opsadmin
fi
run_on_node sshd -t
run_on_node systemctl reload ssh.service
