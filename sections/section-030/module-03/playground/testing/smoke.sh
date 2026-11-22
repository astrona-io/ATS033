#!/usr/bin/env bash
# Smoke test of the start state that docs/overview.md describes.
# scripts/ci/test-playground.sh runs this file inside the playground VM as
# the student user. It exits non-zero when one fact is not as the page says.
set -euo pipefail
cluster="astro-ats-033-playground-030-03"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# The cluster is ready and the workloads of the pages run.
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null

fail() {
  printf 'smoke: %s\n' "$1" >&2
  exit 1
}

# Two probe replicas behind the probe Service, the shuttle and the drifter.
[[ "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" == 2 ]] ||
  fail 'the probe Deployment does not have 2 ready replicas'
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=60s
probe_reply=$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe)
[[ "$probe_reply" == version=v1* ]] || fail "the probe Service answered: $probe_reply"

# The kubelet accepts anonymous requests and allows every request.
kubelet_config=/var/lib/kubelet/config.yaml
sudo grep -A3 '^  anonymous:' "$kubelet_config" | grep -q 'enabled: true' ||
  fail "authentication.anonymous.enabled is not true in $kubelet_config"
sudo grep -qx '  mode: AlwaysAllow' "$kubelet_config" || fail "authorization.mode is not AlwaysAllow in $kubelet_config"
anonymous_status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods)
[[ "$anonymous_status" == 200 ]] || fail "an anonymous request to the kubelet returned $anonymous_status, not 200"
printf 'smoke: start state of %s matches docs/overview.md\n' "$cluster"
