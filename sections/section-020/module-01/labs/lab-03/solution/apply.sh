#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-020-01-03}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing a node container outside this lab\n' >&2
  exit 1
fi
run_on_node() { "$engine" exec "$node_name" "$@"; }

run_on_node gpasswd --delete leaver flight-ops
run_on_node rm -f /etc/sudoers.d/leaver
kubectl -n starfleet-033-020-01-03 delete rolebinding leaver-edit --ignore-not-found
kubectl delete clusterrolebinding leaver-node-reader --ignore-not-found
run_on_node usermod --lock leaver
