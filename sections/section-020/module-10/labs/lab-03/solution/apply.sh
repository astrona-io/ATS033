#!/usr/bin/env bash
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
run_on_node gpasswd --delete leaver flight-ops
run_on_node rm -f /etc/sudoers.d/leaver
kubectl -n "$namespace" delete rolebinding leaver-edit --ignore-not-found
kubectl delete clusterrolebinding leaver-node-reader --ignore-not-found
run_on_node usermod --lock leaver
run_on_node rm -f /home/leaver/.ssh/authorized_keys
