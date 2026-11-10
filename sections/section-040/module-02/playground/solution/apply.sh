#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-040-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-playground-040-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
"$engine" exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
"$engine" cp "$solution_directory/block-rename.json" "$node_name:/var/lib/kubelet/seccomp/profiles/block-rename.json"
kubectl apply -f "$solution_directory/pod-seccomp-block-rename.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/no-rename --timeout=180s
