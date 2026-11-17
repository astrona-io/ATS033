#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-01-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-01-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
# The security team left the profile on the node, outside the kubelet seccomp
# directory. Installing it is part of the task.
"$engine" exec "$node_name" mkdir -p /opt/course/seccomp
"$engine" cp "$lab_directory/bootstrap/profiles/scout-guard.json" "$node_name:/opt/course/seccomp/scout-guard.json"
"$engine" exec "$node_name" rm -f /var/lib/kubelet/seccomp/profiles/scout-guard.json
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
