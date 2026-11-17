#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
worker_ip="$(kubectl get node "$worker_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"

# Allow the worker node, then drop every other new connection to port 19091.
"$engine" exec "$node_name" iptables --append INPUT --protocol tcp --dport 19091 --source "$worker_ip" --jump ACCEPT
"$engine" exec "$node_name" iptables --append INPUT --protocol tcp --dport 19091 --jump DROP
"$engine" exec "$node_name" iptables --list INPUT --numeric --line-numbers
