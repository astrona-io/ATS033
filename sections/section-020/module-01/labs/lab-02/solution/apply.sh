#!/usr/bin/env bash
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
run_on_node usermod --lock --expiredate 1 --shell /usr/sbin/nologin departed-user
run_on_node rm -f /etc/ssh/sshd_config.d/10-migration-access.conf
run_on_node sh -c 'printf "PermitRootLogin no\nPasswordAuthentication no\n" > /etc/ssh/sshd_config.d/10-hardening.conf'
run_on_node sshd -t
run_on_node systemctl reload ssh
