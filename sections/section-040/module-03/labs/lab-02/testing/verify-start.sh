#!/usr/bin/env bash
set -euo pipefail
sudo test -r /sys/kernel/security/apparmor/profiles
sudo sh -c 'echo starting-state > /srv/protected/start-check'
sudo rm /srv/protected/start-check
set +e
output=$(sudo python3 /opt/astrona-apparmor/check.py 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[[ "$status" == 1 && "$output" == 'FAIL: Load training-write-boundary in enforce mode' ]] || exit 2
printf 'PASS: the unfinished profile is deliberately rejected\n'
