#!/usr/bin/env bash
# Reference solution: close olduser and remove the second UID 0 account.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-010-02-02"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-010-02-02"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node usermod --shell /usr/sbin/nologin --lock olduser
# Without --force, userdel refuses because UID 0 is in use by process 1.
run_on_node userdel --force toor
