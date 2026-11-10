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
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
"$engine" exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: false/enabled: true/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" sed -i 's/^  mode: Webhook$/  mode: AlwaysAllow/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" systemctl restart kubelet
sleep 10
kubectl wait --for=condition=Ready "node/$worker_name" --timeout=180s
