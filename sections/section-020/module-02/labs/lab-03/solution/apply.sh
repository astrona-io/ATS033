#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-lab-020-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl delete clusterrole secret-peek-033-020-02-03 --ignore-not-found
kubectl -n starfleet-033-020-02-03 delete rolebinding crew-editors --ignore-not-found
