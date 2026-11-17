#!/usr/bin/env bash
# Run by `astrona test` after the reference solution: wait, with a timeout,
# until the lab settles (restarted kubelets and API servers answer again) and
# every outcome passes, so the graders that follow see the finished state.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output=$(mktemp)
trap 'rm -f "$output"' EXIT
for attempt in $(seq 1 24); do
  if bash "$lab_dir/validate.sh" >"$output" 2>&1; then
    echo "PASS: the reference solution settled (attempt $attempt)"
    exit 0
  fi
  sleep 5
done
cat "$output"
echo 'FAIL: the reference solution did not pass within two minutes' >&2
exit 1
