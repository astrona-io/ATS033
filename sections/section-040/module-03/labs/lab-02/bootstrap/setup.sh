#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-040-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-040-03-02"
source "$lab_directory/bootstrap/helpers.sh"
# The image has AppArmor on. Stop early if that ever changes.
[[ "$(cat /sys/module/apparmor/parameters/enabled)" == Y ]] || { printf 'AppArmor is not enabled in the VM kernel\n' >&2; exit 1; }
# The profile is loaded in enforce mode on the node.
run_on_node cp "$lab_directory/bootstrap/profiles/k8s-deny-tmp-write" /etc/apparmor.d/k8s-deny-tmp-write
run_on_node apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# The console container cannot write its log under the pod-level profile,
# so wait, with a limit, until it has failed at least once.
for attempt in $(seq 1 45); do
  restarts="$(kubectl -n starfleet-033-040-03-02 get pod bridge -o jsonpath='{.status.containerStatuses[?(@.name=="console")].restartCount}' 2>/dev/null || true)"
  if [[ -n "$restarts" && "$restarts" != "0" ]]; then
    exit 0
  fi
  sleep 2
done
printf 'The console container did not fail as expected\n' >&2
exit 1
