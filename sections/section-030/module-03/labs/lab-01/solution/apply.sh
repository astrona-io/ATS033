#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-03-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-03-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
node_name="$cluster-control-plane"
"$engine" exec "$node_name" sed -i 's/--bind-address=0.0.0.0/--bind-address=127.0.0.1/' /etc/kubernetes/manifests/kube-scheduler.yaml
