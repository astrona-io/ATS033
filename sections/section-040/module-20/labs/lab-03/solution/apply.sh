#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-02-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-02-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
"$engine" cp "$lab_directory/solution/cargo-guard.json" "$node_name:/var/lib/kubelet/seccomp/profiles/cargo-guard.json"
# The kubelet reads the profile only when it creates a container.
kubectl -n starfleet-033-040-02-03 rollout restart deployment/shuttle
kubectl -n starfleet-033-040-02-03 rollout status deployment/shuttle --timeout=180s
