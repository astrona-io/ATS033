#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-030-03-03"
source "$lab_directory/bootstrap/helpers.sh"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"

# Weaken the kubelet: accept anonymous requests and allow every request.
run_on_worker sed -i '/^authentication:/,/^  webhook:/ s/enabled: false/enabled: true/' /var/lib/kubelet/config.yaml
run_on_worker sed -i 's/^  mode: Webhook$/  mode: AlwaysAllow/' /var/lib/kubelet/config.yaml
run_on_worker systemctl restart kubelet

# Wait until the restarted kubelet serves the weak configuration.
status=""
for attempt in $(seq 1 60); do
  status="$(run_on_worker curl -sk -o /dev/null -w '%{http_code}' -m 3 https://127.0.0.1:10250/pods || true)"
  if [[ "$status" == 200 ]]; then
    break
  fi
  sleep 2
done
if [[ "$status" != 200 ]]; then
  printf 'The kubelet did not come back with anonymous access\n' >&2
  exit 1
fi
wait_for_worker
