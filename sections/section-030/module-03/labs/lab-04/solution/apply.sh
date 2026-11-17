#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-03-04}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-03-04}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
node_name="$cluster-control-plane"
"$engine" exec "$node_name" chmod 700 /var/lib/etcd
