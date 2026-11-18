#!/usr/bin/env bash
# Smoke test of the start state that docs/overview.md describes.
# scripts/ci/test-playground.sh runs this file inside the playground VM as
# the student user, after validate.sh. It exits non-zero when one fact is
# not as the page says.
set -euo pipefail
cluster="astro-ats-033-playground-040-03"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

fail() {
  printf 'smoke: %s\n' "$1" >&2
  exit 1
}

# The kernel has AppArmor enabled.
[[ "$(cat /sys/module/apparmor/parameters/enabled)" == Y ]] || fail 'AppArmor is not enabled in the kernel'

# Two probe pods and the shuttle run in starfleet, and no hardened pod exists yet.
[[ "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" == 2 ]] ||
  fail 'the probe Deployment does not have 2 ready replicas'
probe_reply=$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe)
[[ "$probe_reply" == version=v1* ]] || fail "the probe Service answered: $probe_reply"
if kubectl -n starfleet get pod bind-only >/dev/null 2>&1; then
  fail 'the pod bind-only already exists'
fi
printf 'smoke: start state of %s matches docs/overview.md\n' "$cluster"
