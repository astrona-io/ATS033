#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Builds a small Debian package on the node with dpkg-deb (no
# network access needed) and installs it. The package ships a program, a
# configuration file and a systemd service that Kubernetes does not need.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-010-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="astro-ats-033-lab-010-01-02"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-033-010-01-02"
source "$lab_directory/bootstrap/helpers.sh"
run_on_node bash -s <<'BUILD'
set -euo pipefail
build_root=$(mktemp -d)
mkdir -p "$build_root/DEBIAN" "$build_root/usr/sbin" "$build_root/etc/debug-relay" "$build_root/usr/lib/systemd/system"
cat > "$build_root/DEBIAN/control" <<'CONTROL'
Package: debug-relay
Version: 1.4.2
Architecture: all
Maintainer: Image Build Team <image-build@example.com>
Depends: python3
Section: admin
Priority: optional
Description: HTTP relay that serves node log files for debugging
 Installed by an old image build to read node logs over HTTP.
CONTROL
printf '/etc/debug-relay/relay.conf\n' > "$build_root/DEBIAN/conffiles"
cat > "$build_root/DEBIAN/postinst" <<'SCRIPT'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  systemctl daemon-reload
  systemctl enable --now debug-relay.service
fi
SCRIPT
cat > "$build_root/DEBIAN/prerm" <<'SCRIPT'
#!/bin/sh
set -e
systemctl disable --now debug-relay.service || true
SCRIPT
cat > "$build_root/DEBIAN/postrm" <<'SCRIPT'
#!/bin/sh
set -e
systemctl daemon-reload || true
SCRIPT
cat > "$build_root/usr/sbin/debug-relay" <<'SCRIPT'
#!/bin/sh
exec /usr/bin/python3 -m http.server "${RELAY_PORT:-7070}" --bind 127.0.0.1 --directory /var/log
SCRIPT
printf 'RELAY_PORT=7070\n' > "$build_root/etc/debug-relay/relay.conf"
cat > "$build_root/usr/lib/systemd/system/debug-relay.service" <<'UNIT'
[Unit]
Description=Debug relay for node log files
After=network.target

[Service]
EnvironmentFile=/etc/debug-relay/relay.conf
ExecStart=/usr/sbin/debug-relay
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
chmod 0755 "$build_root/DEBIAN/postinst" "$build_root/DEBIAN/prerm" "$build_root/DEBIAN/postrm" "$build_root/usr/sbin/debug-relay"
dpkg-deb --root-owner-group --build "$build_root" /tmp/debug-relay_1.4.2_all.deb >/dev/null
dpkg --install /tmp/debug-relay_1.4.2_all.deb >/dev/null
rm -rf "$build_root" /tmp/debug-relay_1.4.2_all.deb
for attempt in $(seq 1 30); do
  if ss -Htln 'sport = :7070' | grep -q LISTEN; then
    exit 0
  fi
  sleep 1
done
echo 'The debug-relay service did not open port 7070' >&2
exit 1
BUILD
