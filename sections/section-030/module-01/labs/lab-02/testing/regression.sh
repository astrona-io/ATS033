#!/usr/bin/env bash
set -euo pipefail

for outcome in source-boundary port-boundary; do sudo python3 /opt/astrona-live/check.py "$outcome"; done
sudo nft list table inet training | sudo tee /opt/astrona-live/solved.nft >/dev/null
restore() { sudo nft delete table inet training; sudo nft -f /opt/astrona-live/solved.nft; }
trap restore EXIT
sudo nft flush chain inet training input
set +e
output=$(sudo python3 /opt/astrona-live/check.py source-boundary); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Reject the untrusted client on port 8080' ]]
sudo nft 'add rule inet training input iifname "lab-untrusted" meta l4proto tcp reject with tcp reset'
set +e
output=$(sudo python3 /opt/astrona-live/check.py port-boundary); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Keep public port 8081 reachable from both peers' ]]
restore
trap - EXIT
