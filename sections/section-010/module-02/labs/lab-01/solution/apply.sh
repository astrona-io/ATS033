#!/usr/bin/env bash
set -euo pipefail

sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/;s/^PasswordAuthentication .*/PasswordAuthentication no/;s/^AllowUsers .*/AllowUsers opsadmin/' /etc/ssh/sshd_config.training
sudo usermod -L -s /usr/sbin/nologin olduser
sudo /usr/sbin/sshd -t -f /etc/ssh/sshd_config.training
sudo systemctl reload training-sshd
sleep 1
