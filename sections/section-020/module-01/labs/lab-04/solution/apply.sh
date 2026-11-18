#!/usr/bin/env bash
# Reference solution: a persistent watch rule in rules.d, loaded with
# augenrules, and only then the new sudoers file, so that auditd records it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-020-01-04}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-020-01-04"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-020-01-04"
source "$lab_directory/bootstrap/helpers.sh"
printf -- '-w /etc/sudoers.d -p wa -k sudoers-change\n' | run_on_node tee /etc/audit/rules.d/40-sudoers.rules >/dev/null
run_on_node augenrules --load >/dev/null
printf 'oncall ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet\n' | run_on_node tee /etc/sudoers.d/40-oncall >/dev/null
run_on_node chmod 0440 /etc/sudoers.d/40-oncall
run_on_node visudo -c
