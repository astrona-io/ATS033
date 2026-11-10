#!/usr/bin/env bash
# Run by `astrona test` before the reference solution. Every outcome must fail
# on the unfinished lab, and fail with a grading result rather than a crash.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
output=$(mktemp)
trap 'rm -f "$output"' EXIT
for grader in "$lab_dir"/validation/validate-*.sh; do
  outcome=$(basename "$grader" .sh)
  outcome=${outcome#validate-}
  status=0
  bash "$grader" >"$output" 2>&1 || status=$?
  if [ "$status" -eq 0 ]; then
    cat "$output"
    fail "$outcome passed on the unfinished lab"
  fi
  if [ "$status" -ne 1 ] || ! grep -q '^FAIL:' "$output" || grep -q '^FAIL: Unknown outcome' "$output"; then
    cat "$output"
    fail "$outcome failed without a grading result"
  fi
  echo "$outcome: $(grep -m1 '^FAIL:' "$output")"
done
echo 'PASS: every outcome fails on the unfinished lab'
