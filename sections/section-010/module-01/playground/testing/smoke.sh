#!/usr/bin/env bash
# Smoke test of the start state that docs/overview.md describes.
# scripts/ci/test-playground.sh runs this file inside the playground VM as
# the student user. It exits non-zero when one fact is not as the page says.
set -euo pipefail
cluster="astro-ats-033-playground-010-01"
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

# The pages use these pods and the probe Service.
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=60s
probe_reply=$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe)
[[ "$probe_reply" == version=v1* ]] || fail "the probe Service answered: $probe_reply"

# The unneeded service runs and starts at boot, so the practice can turn it off.
[[ "$(systemctl is-active training-extra.service)" == active ]] || fail 'training-extra.service is not active'
[[ "$(systemctl is-enabled training-extra.service)" == enabled ]] || fail 'training-extra.service is not enabled'
systemctl cat training-extra.service | grep -qx 'ExecStart=/bin/sleep 3600' ||
  fail 'training-extra.service does not run /bin/sleep 3600'
dpkg-query -W -f='${Status}' node-diag-tools | grep -q 'install ok installed' ||
  fail 'the package node-diag-tools is not installed'

# The node services that the practice checks at the end.
for service in kubelet.service containerd.service; do
  [[ "$(systemctl is-active "$service")" == active ]] || fail "$service is not active"
done
kubectl get node "$cluster" --no-headers | grep -qw Ready || fail "node $cluster is not Ready"
printf 'smoke: start state of %s matches docs/overview.md\n' "$cluster"
