#!/usr/bin/env bash
# Seeds a systemd service on the control-plane node that serves files over
# HTTP on TCP port 8099. Kubernetes does not need it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-010-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-010-01-01}"
node_name="$cluster-control-plane"
if [[ "$("$engine" inspect "$node_name" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}')" != "$cluster" ]]; then
  printf 'Refusing an unrelated node container\n' >&2
  exit 1
fi
"$engine" exec -i "$node_name" tee /usr/lib/systemd/system/remote-diag.service >/dev/null <<'UNIT'
[Unit]
Description=Remote diagnostics web console
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8099 --bind 0.0.0.0 --directory /usr/share/doc
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
"$engine" exec "$node_name" systemctl daemon-reload
"$engine" exec "$node_name" systemctl enable --now remote-diag.service
for attempt in $(seq 1 30); do
  if "$engine" exec "$node_name" ss -Htln 'sport = :8099' | grep -q LISTEN; then
    exit 0
  fi
  sleep 1
done
printf 'The seeded service did not open port 8099\n' >&2
exit 1
