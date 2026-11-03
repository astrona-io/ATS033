#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-lab-040-02-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster_name="astro-ats-033-lab-040-02-01"
node_name="$cluster_name-control-plane"
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman cp "$solution_directory/block-delete.json" "$node_name:/var/lib/kubelet/seccomp/profiles/block-delete.json"
kubectl apply -f "$solution_directory/pod-seccomp-block-delete.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/no-delete --timeout=180s
