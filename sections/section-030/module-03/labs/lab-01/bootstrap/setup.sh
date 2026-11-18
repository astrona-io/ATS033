#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-030-03-01"
source "$lab_directory/bootstrap/helpers.sh"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/shuttle --timeout=180s

# Widen the scheduler listener: bind port 10259 on every address of the node.
edit_manifest kube-scheduler 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/'

# Wait until the kubelet has restarted the scheduler with the wide listener.
listening=no
for attempt in $(seq 1 90); do
  if run_on_node ss -tln | grep -Eq '(\*|0\.0\.0\.0|\[::\]):10259 '; then
    listening=yes
    break
  fi
  sleep 2
done
if [[ "$listening" != yes ]]; then
  printf 'kube-scheduler did not start listening on all addresses\n' >&2
  exit 1
fi
wait_for_pod_ready "kube-scheduler-$node_name" True
