#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-capstone-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-capstone-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

kubectl -n starfleet delete pod node-local-server --ignore-not-found --wait=true
sed "s/astro-ats-033-lab-030-capstone-01-control-plane/$cluster-control-plane/" "$solution_directory/pod-node-local-server.yaml" | kubectl apply -f -
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
kubectl apply -f "$solution_directory/service-probe-debug.yaml"
kubectl apply -f "$solution_directory/service-probe-public.yaml"
"$engine" exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" systemctl restart kubelet
sleep 10
kubectl wait --for=condition=Ready "node/$worker_name" --timeout=180s
