#!/usr/bin/env bash
set -euo pipefail
profile=/etc/apparmor.d/training-write-boundary
backup=$(mktemp)
sudo cat "$profile" > "$backup"
restore() { sudo cp "$backup" "$profile"; sudo apparmor_parser -r "$profile"; rm -f "$backup"; }
trap restore EXIT
expect_failure() {
  set +e
  output=$(sudo python3 /opt/astrona-apparmor/check.py 2>&1)
  status=$?
  set -e
  printf '%s\n' "$output"
  [[ "$status" == 1 && "$output" == "FAIL: $1" ]] || exit 2
}
sudo apparmor_parser -r -C "$profile"
expect_failure 'Load training-write-boundary in enforce mode'
sed '/deny \/srv\/protected/d' "$backup" | sudo tee "$profile" >/dev/null
sudo apparmor_parser -r "$profile"
expect_failure 'AppArmor must deny a fresh write in /srv/protected'
sed 's@deny /srv/protected/\*\* w,@deny /srv/** w,@' "$backup" | sudo tee "$profile" >/dev/null
sudo apparmor_parser -r "$profile"
expect_failure 'Confined writes in /srv/allowed must work'
printf 'PASS: complain mode, missing denial and an overbroad profile are rejected\n'
