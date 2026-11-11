#!/usr/bin/env bash
set -euo pipefail
sudo tee /etc/apparmor.d/training-write-boundary >/dev/null <<'PROFILE'
#include <tunables/global>
profile training-write-boundary {
  #include <abstractions/base>
  file,
  network,
  capability,
  deny /srv/protected/** w,
}
PROFILE
sudo apparmor_parser -r /etc/apparmor.d/training-write-boundary
