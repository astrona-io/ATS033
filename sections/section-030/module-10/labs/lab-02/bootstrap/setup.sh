#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-033-lab-030-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
for pod in node-metrics-server shuttle; do
  kubectl -n starfleet-033-030-01-02 wait --for=condition=Ready "pod/$pod" --timeout=300s
done

# ufw stays inactive. Its default policies are set to allow incoming and
# routed traffic, so turning ufw on keeps SSH, the API server and pod traffic
# working; the learner adds only the rule for port 19091.
sudo ufw --force disable
sudo ufw default allow incoming
sudo ufw default allow routed
