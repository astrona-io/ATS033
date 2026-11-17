#!/usr/bin/env bash
# Reference solution: close olduser and remove the second UID 0 account.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-010-02-02}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing an unrelated node container\n' >&2
  exit 1
fi
"$engine" exec "$node_name" usermod --shell /usr/sbin/nologin --lock olduser
# Without --force, userdel refuses because UID 0 is in use by process 1.
"$engine" exec "$node_name" userdel --force toor
