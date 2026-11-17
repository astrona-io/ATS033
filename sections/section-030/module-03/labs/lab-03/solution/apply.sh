#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-03-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-03-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
worker_name="$cluster-worker"
"$engine" exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" systemctl restart kubelet
kubectl wait --for=condition=Ready "node/$worker_name" --timeout=180s
