#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-030-03-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-030-03-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-033-030-03-01 wait --for=condition=Ready pod/shuttle --timeout=180s

# Widen the scheduler listener: bind port 10259 on every address of the node.
"$engine" exec "$node_name" sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-scheduler.yaml

# Wait until the kubelet has restarted the scheduler with the wide listener.
listening=no
for attempt in $(seq 1 90); do
  if "$engine" exec "$node_name" ss -tln | grep -Eq '(\*|0\.0\.0\.0|\[::\]):10259 '; then
    listening=yes
    break
  fi
  sleep 2
done
if [[ "$listening" != yes ]]; then
  printf 'kube-scheduler did not start listening on all addresses\n' >&2
  exit 1
fi
kubectl -n kube-system wait --for=condition=Ready "pod/kube-scheduler-$node_name" --timeout=180s
