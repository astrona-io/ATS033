#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-033-playground-040-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
if bash "$lab_directory/validate.sh"; then
  printf 'Starting state unexpectedly passes grading\n' >&2
  exit 1
fi
bash "$lab_directory/solution/apply.sh"
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if bash "$lab_directory/validate.sh"; then exit 0; fi
  sleep 2
done
printf 'Reference result did not pass within the bounded retry period\n' >&2
exit 1
