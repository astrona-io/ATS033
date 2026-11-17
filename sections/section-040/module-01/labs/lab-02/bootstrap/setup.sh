#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_names=("$cluster-control-plane" "$cluster-worker")

stop_without_apparmor() {
  printf 'Stopping: this lab needs a host with AppArmor, for example an Ubuntu Linux machine (%s)\n' "$1" >&2
  exit 1
}

# Check every node first, so nothing is changed on a host without AppArmor.
for node_name in "${node_names[@]}"; do
  enabled="$("$engine" exec "$node_name" cat /sys/module/apparmor/parameters/enabled 2>/dev/null || true)"
  [[ "$enabled" == "Y" ]] || stop_without_apparmor "AppArmor is not enabled in the kernel of $node_name"
done

for node_name in "${node_names[@]}"; do
  restart_needed=no
  if ! "$engine" exec "$node_name" test -d /sys/kernel/security/apparmor; then
    "$engine" exec "$node_name" mount -t securityfs securityfs /sys/kernel/security \
      || stop_without_apparmor "securityfs cannot be mounted on $node_name"
    restart_needed=yes
  fi
  if ! "$engine" exec "$node_name" sh -c 'command -v apparmor_parser' >/dev/null; then
    "$engine" exec "$node_name" timeout 300 sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends apparmor' >/dev/null \
      || stop_without_apparmor "apparmor_parser could not be installed on $node_name"
    restart_needed=yes
  fi
  "$engine" exec "$node_name" test -d /sys/kernel/security/apparmor \
    || stop_without_apparmor "the AppArmor interface is missing on $node_name"
  if [[ "$restart_needed" == yes ]]; then
    # containerd and the kubelet detect AppArmor when they start.
    "$engine" exec "$node_name" systemctl restart containerd kubelet
  fi
done
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
