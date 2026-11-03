#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-030-capstone-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-033-lab-030-capstone-01-control-plane"
worker_name="astro-ats-033-lab-030-capstone-01-worker"

kubectl -n starfleet delete pod node-local-server --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-node-local-server.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
kubectl apply -f "$solution_directory/service-probe-debug.yaml"
kubectl apply -f "$solution_directory/service-probe-public.yaml"
podman exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
podman exec "$worker_name" systemctl restart kubelet
sleep 10
kubectl wait --for=condition=Ready "node/$worker_name" --timeout=180s
