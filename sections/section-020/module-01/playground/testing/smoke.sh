#!/usr/bin/env bash
# Smoke test of the start state that docs/overview.md describes.
# scripts/ci/test-playground.sh runs this file inside the playground VM as
# the student user, after validate.sh. It exits non-zero when one fact is
# not as the page says.
set -euo pipefail
cluster="astro-ats-033-playground-020-01"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

fail() {
  printf 'smoke: %s\n' "$1" >&2
  exit 1
}

kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=60s
probe_reply=$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe)
[[ "$probe_reply" == version=v1* ]] || fail "the probe Service answered: $probe_reply"
if kubectl -n starfleet get configmap identity-review >/dev/null 2>&1; then
  fail 'the ConfigMap identity-review already exists'
fi

# The account, the group and the two reports, with the owners and modes the
# page shows.
getent group training-readers >/dev/null || fail 'the group training-readers does not exist'
id training-reader >/dev/null || fail 'the account training-reader does not exist'
if id -nG training-reader | grep -qw training-readers; then
  fail 'training-reader is already in the group training-readers'
fi
report_directory=/var/lib/training-identity
[[ "$(sudo stat -c '%A %U %G' "$report_directory/public-report")" == '-rw-r----- root training-readers' ]] ||
  fail 'public-report does not have mode -rw-r----- and owner root:training-readers'
[[ "$(sudo stat -c '%A %U %G' "$report_directory/private-report")" == '-rw------- root root' ]] ||
  fail 'private-report does not have mode -rw------- and owner root:root'

# The account cannot read either report yet.
for report in public-report private-report; do
  if sudo runuser -u training-reader -- cat "$report_directory/$report" >/dev/null 2>&1; then
    fail "training-reader can already read $report"
  fi
done
printf 'smoke: start state of %s matches docs/overview.md\n' "$cluster"
