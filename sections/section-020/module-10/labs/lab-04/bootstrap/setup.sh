#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# auditd runs with the image defaults plus one persistent watch rule on
# /etc/sudoers that the learner must keep. The account oncall exists and has
# no sudo rule yet; nothing watches /etc/sudoers.d.
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
if ! id oncall >/dev/null 2>&1; then
  run_on_node useradd --create-home --shell /bin/bash oncall
fi
printf -- '-w /etc/sudoers -p wa -k sudoers-main\n' | run_on_node tee /etc/audit/rules.d/30-sudoers-main.rules >/dev/null
# augenrules --load prints the audit status three times; the rule list below
# is the useful check.
run_on_node augenrules --load >/dev/null
run_on_node auditctl -l
