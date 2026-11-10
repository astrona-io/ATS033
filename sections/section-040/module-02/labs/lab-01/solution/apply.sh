#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-02-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-02-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
"$engine" exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
"$engine" cp "$solution_directory/block-delete.json" "$node_name:/var/lib/kubelet/seccomp/profiles/block-delete.json"
kubectl apply -f "$solution_directory/pod-seccomp-block-delete.yaml"
kubectl -n starfleet-033-040-02-01 wait --for=condition=Ready pod/no-delete --timeout=180s
