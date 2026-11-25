#!/usr/bin/env bash
# Runs inside the lab VM.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# Deny every new TCP connection to port 19091 that does not come from the
# node itself (ufw always accepts the loopback interface), then turn ufw on.
sudo ufw deny 19091/tcp
sudo ufw --force enable
sudo ufw status numbered
