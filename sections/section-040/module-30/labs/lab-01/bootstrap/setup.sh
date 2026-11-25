#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-040-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-040-03-01"
source "$lab_directory/bootstrap/helpers.sh"
# The image has AppArmor on. Stop early if that ever changes.
[[ "$(cat /sys/module/apparmor/parameters/enabled)" == Y ]] || { printf 'AppArmor is not enabled in the VM kernel\n' >&2; exit 1; }
# The profile starts in complain mode on the node.
run_on_node cp "$lab_directory/bootstrap/profiles/k8s-deny-etc-write" /etc/apparmor.d/k8s-deny-etc-write
run_on_node apparmor_parser -r -C /etc/apparmor.d/k8s-deny-etc-write
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-033-040-03-01 rollout status deployment/scout --timeout=180s
