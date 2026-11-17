#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-03-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-03-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker_name="$cluster-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"

# Weaken the worker kubelet: accept anonymous requests and allow every request.
"$engine" exec "$worker_name" sed -i '/^authentication:/,/^  webhook:/ s/enabled: false/enabled: true/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" sed -i 's/^  mode: Webhook$/  mode: AlwaysAllow/' /var/lib/kubelet/config.yaml
"$engine" exec "$worker_name" systemctl restart kubelet

# Wait until the restarted kubelet serves the weak configuration.
for attempt in $(seq 1 60); do
  status="$("$engine" exec "$worker_name" curl -sk -o /dev/null -w '%{http_code}' -m 3 https://127.0.0.1:10250/pods || true)"
  if [[ "$status" == 200 ]]; then
    break
  fi
  sleep 2
done
if [[ "$status" != 200 ]]; then
  printf 'The worker kubelet did not come back with anonymous access\n' >&2
  exit 1
fi
kubectl wait --for=condition=Ready "node/$worker_name" --timeout=180s
