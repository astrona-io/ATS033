#!/usr/bin/env bash
set -euo pipefail

sudo cp /etc/ssh/sshd_config.training /opt/training-ssh/solved.conf
restore() { sudo cp /opt/training-ssh/solved.conf /etc/ssh/sshd_config.training; sudo systemctl reload training-sshd; }
trap restore EXIT
for outcome in root-login password-login account-access; do sudo python3 /opt/astrona-live/check.py "$outcome"; done
# Reopening each authentication method must be detected by a fresh connection.
sudo sed -i 's/^PermitRootLogin no/PermitRootLogin yes/;s/^AllowUsers .*/AllowUsers opsadmin root/' /etc/ssh/sshd_config.training
sudo systemctl reload training-sshd
sleep 1
set +e
output=$(sudo python3 /opt/astrona-live/check.py root-login); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Reject root key authentication' ]]
restore
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.training
sudo systemctl reload training-sshd
sleep 1
set +e
output=$(sudo python3 /opt/astrona-live/check.py password-login); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Reject password authentication' ]]
restore
