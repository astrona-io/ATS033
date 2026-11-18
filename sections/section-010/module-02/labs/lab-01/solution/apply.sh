#!/usr/bin/env bash
# Reference solution: fix the drop-in values that sshd reads first, add a
# global AllowUsers drop-in file and reload the running server.
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
run_on_node sed -i 's/^permitrootlogin .*/PermitRootLogin no/I' /etc/ssh/sshd_config.d/10-legacy-root.conf
run_on_node sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
printf 'AllowUsers opsadmin student astrona\n' | run_on_node tee /etc/ssh/sshd_config.d/10-allow-users.conf >/dev/null
run_on_node sshd -t
run_on_node systemctl reload ssh.service
