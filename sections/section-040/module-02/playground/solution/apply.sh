#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-033-playground-040-02" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster_name="astro-ats-033-playground-040-02"
node_name="$cluster_name-control-plane"
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman cp "$solution_directory/block-rename.json" "$node_name:/var/lib/kubelet/seccomp/profiles/block-rename.json"
kubectl apply -f "$solution_directory/pod-seccomp-block-rename.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/no-rename --timeout=180s
