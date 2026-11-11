#!/usr/bin/env bash
set -euo pipefail

sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server openssh-client sshpass python3
sudo install -d -m 0755 /opt/training-ssh /opt/training-ssh/authorized_keys /run/sshd
for account in opsadmin olduser; do
  sudo useradd -m -s /bin/bash "$account"
  printf '%s:training-password\n' "$account" | sudo chpasswd
done
sudo ssh-keygen -q -t ed25519 -N '' -f /opt/training-ssh/client
sudo chmod 0600 /opt/training-ssh/client
for account in opsadmin olduser root; do
  sudo cp /opt/training-ssh/client.pub "/opt/training-ssh/authorized_keys/$account"
done
sudo tee /etc/ssh/sshd_config.training >/dev/null <<'CONF'
Port 2222
ListenAddress 127.0.0.1
HostKey /etc/ssh/ssh_host_ed25519_key
PidFile /run/training-sshd.pid
AuthorizedKeysFile /opt/training-ssh/authorized_keys/%u
UsePAM yes
KbdInteractiveAuthentication no
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AllowUsers opsadmin olduser root
CONF
sudo tee /etc/systemd/system/training-sshd.service >/dev/null <<'UNIT'
[Unit]
Description=Isolated SSH authentication exercise
After=network.target
[Service]
ExecStart=/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config.training
ExecReload=/bin/kill -HUP $MAINPID
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now training-sshd

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import subprocess, sys
def run(args):
    return subprocess.run(args, text=True, capture_output=True, timeout=12)
def login(account, password=False):
    args=['ssh','-p','2222','-o','ConnectTimeout=4','-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=/dev/null','-o','LogLevel=ERROR','-o','IdentitiesOnly=yes']
    if password:
        args=['sshpass','-p','training-password',*args,'-o','PreferredAuthentications=password','-o','PubkeyAuthentication=no','-o','NumberOfPasswordPrompts=1']
    else:
        args+=['-o','BatchMode=yes','-i','/opt/training-ssh/client','-o','PreferredAuthentications=publickey']
    return run([*args,account+'@127.0.0.1','id -un'])
def denied(result, message):
    assert result.returncode != 0, message
    if result.returncode != 255 or 'Permission denied' not in result.stderr:
        raise RuntimeError('Expected authentication refusal: '+result.stderr)
def check(outcome):
    if run(['systemctl','is-active','training-sshd']).returncode:
        raise RuntimeError('training-sshd must be running')
    admin=login('opsadmin')
    assert admin.returncode == 0 and admin.stdout.strip()=='opsadmin', 'Preserve a working opsadmin key login'
    if outcome=='root-login': denied(login('root'), 'Reject root key authentication')
    elif outcome=='password-login': denied(login('opsadmin',True), 'Reject password authentication')
    elif outcome=='account-access':
        denied(login('olduser'), 'Reject olduser key authentication')
        status=run(['passwd','-S','olduser'])
        assert status.returncode==0 and status.stdout.split()[1]=='L', 'Lock olduser password'
        assert run(['getent','passwd','olduser']).stdout.strip().split(':')[-1]=='/usr/sbin/nologin', 'Give olduser a nologin shell'
        effective=run(['/usr/sbin/sshd','-T','-f','/etc/ssh/sshd_config.training','-C','user=opsadmin,host=localhost,addr=127.0.0.1'])
        assert effective.returncode==0 and 'allowusers opsadmin\n' in effective.stdout, 'Allow only opsadmin on the training listener'
    else: raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
