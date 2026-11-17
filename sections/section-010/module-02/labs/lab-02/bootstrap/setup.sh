#!/usr/bin/env bash
# Seeds three accounts on the control-plane node: opsadmin (the administrator
# account, which must stay usable), olduser (unused, with a password and a
# login shell) and toor (a second account with UID 0).
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
account_exists() { "$engine" exec "$node_name" id "$1" >/dev/null 2>&1; }
if ! account_exists opsadmin; then
  "$engine" exec "$node_name" useradd --create-home --shell /bin/bash opsadmin
fi
if ! account_exists olduser; then
  "$engine" exec "$node_name" useradd --create-home --shell /bin/bash olduser
fi
if ! "$engine" exec "$node_name" getent passwd toor >/dev/null 2>&1; then
  "$engine" exec "$node_name" useradd --non-unique --uid 0 --gid 0 --home-dir /nonexistent --no-create-home --shell /bin/bash toor
fi
# chpasswd hashes each password before it writes /etc/shadow.
printf 'opsadmin:Ops-Admin-2026\nolduser:Retired-2019\ntoor:Maintenance-2018\n' | "$engine" exec -i "$node_name" chpasswd
