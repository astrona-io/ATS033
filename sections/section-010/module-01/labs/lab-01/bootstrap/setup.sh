#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Seeds a systemd service that serves files over HTTP on TCP port 8099.
# Kubernetes does not need it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-010-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-010-01-01"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-010-01-01"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node tee /usr/lib/systemd/system/remote-diag.service >/dev/null <<'UNIT'
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
run_on_node systemctl daemon-reload
run_on_node systemctl enable --now remote-diag.service
for attempt in $(seq 1 30); do
  if run_on_node ss -Htln 'sport = :8099' | grep -q LISTEN; then
    exit 0
  fi
  sleep 1
done
printf 'The seeded service did not open port 8099\n' >&2
exit 1
