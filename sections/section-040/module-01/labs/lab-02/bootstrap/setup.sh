#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-040-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-040-01-02"
source "$lab_directory/bootstrap/helpers.sh"
# The image has AppArmor on. Stop early if that ever changes.
[[ "$(cat /sys/module/apparmor/parameters/enabled)" == Y ]] || { printf 'AppArmor is not enabled in the VM kernel\n' >&2; exit 1; }
# The learner writes and loads the profile, so start without it.
run_on_node rm -f /etc/apparmor.d/k8s-deny-tmp-write
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
