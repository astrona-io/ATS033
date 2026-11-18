#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Seeds three accounts on the node: opsadmin (the administrator
# account, which must stay usable), olduser (unused, with a password and a
# login shell) and toor (a second account with UID 0).
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
account_exists() { id "$1" >/dev/null 2>&1; }
if ! account_exists opsadmin; then
  run_on_node useradd --create-home --shell /bin/bash opsadmin
fi
if ! account_exists olduser; then
  run_on_node useradd --create-home --shell /bin/bash olduser
fi
if ! getent passwd toor >/dev/null 2>&1; then
  run_on_node useradd --non-unique --uid 0 --gid 0 --home-dir /nonexistent --no-create-home --shell /bin/bash toor
fi
# chpasswd hashes each password before it writes /etc/shadow.
printf 'opsadmin:Ops-Admin-2026\nolduser:Retired-2019\ntoor:Maintenance-2018\n' | run_on_node chpasswd
