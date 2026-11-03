#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-040-capstone-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
cluster_name="astro-ats-033-lab-040-capstone-01"
node_name="$cluster_name-control-plane"
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman cp "$lab_directory/bootstrap/profiles/cargo-guard.json" "$node_name:/var/lib/kubelet/seccomp/profiles/cargo-guard.json"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
