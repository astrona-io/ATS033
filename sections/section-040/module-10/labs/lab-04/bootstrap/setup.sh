#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-01-04}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-01-04}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
# The approved profile is installed correctly. The Deployment refers to it
# with a typo, so its pod cannot start.
"$engine" exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
"$engine" cp "$lab_directory/bootstrap/profiles/shuttle-guard.json" "$node_name:/var/lib/kubelet/seccomp/profiles/shuttle-guard.json"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# Wait, with a limit, until the kubelet has reported the failure, so the
# learner finds the broken state and not a pod that is still being created.
for attempt in $(seq 1 30); do
  reason="$(kubectl -n starfleet-033-040-01-04 get pods -l app=shuttle -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}')"
  if [[ "$reason" == *CreateContainerError* ]]; then
    exit 0
  fi
  sleep 2
done
printf 'The shuttle pod did not reach CreateContainerError\n' >&2
exit 1
