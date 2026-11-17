#!/usr/bin/env bash
# Writes a stand-in SSH server configuration on the control-plane node. The
# kind node image has no sshd, so the grader reads these files the way sshd
# reads them. Two drop-in files are read before the main file and loosen it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-010-02-01}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing an unrelated node container\n' >&2
  exit 1
fi
"$engine" exec "$node_name" mkdir -p /etc/ssh/sshd_config.d
"$engine" exec -i "$node_name" tee /etc/ssh/sshd_config >/dev/null <<'MAIN'
# Main configuration file of the SSH server.
Include /etc/ssh/sshd_config.d/*.conf

Port 22
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
Subsystem sftp internal-sftp

Match User backup
    # The backup account may only copy files.
    ForceCommand internal-sftp
    AllowTcpForwarding no
MAIN
"$engine" exec -i "$node_name" tee /etc/ssh/sshd_config.d/10-legacy-root.conf >/dev/null <<'LEGACY'
# Added during the first install so that root could copy files.
permitrootlogin yes
LEGACY
"$engine" exec -i "$node_name" tee /etc/ssh/sshd_config.d/50-cloud-init.conf >/dev/null <<'CLOUD'
PasswordAuthentication yes
CLOUD
if ! "$engine" exec "$node_name" id opsadmin >/dev/null 2>&1; then
  "$engine" exec "$node_name" useradd --create-home --shell /bin/bash opsadmin
fi
