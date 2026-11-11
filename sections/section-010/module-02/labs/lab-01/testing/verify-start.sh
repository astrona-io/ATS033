#!/usr/bin/env bash
set -euo pipefail
for outcome in root-login password-login account-access; do
  set +e
  output=$(sudo python3 /opt/astrona-live/check.py "$outcome" 2>&1)
  status=$?
  set -e
  printf '%s\n' "$output"
  [[ "$status" == 1 && "$output" == FAIL:* ]] || exit 2
done
