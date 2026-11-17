#!/usr/bin/env bash
# Reference solution: fix the drop-in values that sshd reads first and add a
# global AllowUsers line above the Match block.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-010-02-01}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing an unrelated node container\n' >&2
  exit 1
fi
"$engine" exec "$node_name" sed -i 's/^permitrootlogin .*/PermitRootLogin no/I' /etc/ssh/sshd_config.d/10-legacy-root.conf
"$engine" exec "$node_name" sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
"$engine" exec "$node_name" sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
"$engine" exec "$node_name" sed -i '/^Match User backup/i AllowUsers opsadmin\n' /etc/ssh/sshd_config
