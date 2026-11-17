#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-040-02-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-033-lab-040-02-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
# The installed profile blocks one family of system calls too many.
"$engine" exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
"$engine" cp "$lab_directory/bootstrap/profiles/cargo-guard.json" "$node_name:/var/lib/kubelet/seccomp/profiles/cargo-guard.json"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# Wait, with a limit, until the container has failed at least once, so the
# learner finds the broken state.
for attempt in $(seq 1 45); do
  restarts="$(kubectl -n starfleet-033-040-02-03 get pods -l app=shuttle -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}')"
  if [[ -n "$restarts" && "$restarts" != "0" ]]; then
    exit 0
  fi
  sleep 2
done
printf 'The shuttle container did not fail as expected\n' >&2
exit 1
