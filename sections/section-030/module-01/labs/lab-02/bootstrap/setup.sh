#!/usr/bin/env bash
set -euo pipefail

sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nftables iproute2 curl python3 iputils-ping
sudo ip netns add trusted
sudo ip netns add untrusted
for entry in 'trusted 192.0.2' 'untrusted 198.51.100'; do
  read -r peer network <<<"$entry"
  sudo ip link add "lab-$peer" type veth peer name peer0 netns "$peer"
  sudo ip addr add "$network.1/24" dev "lab-$peer"
  sudo ip link set "lab-$peer" up
  sudo ip netns exec "$peer" ip addr add "$network.2/24" dev peer0
  sudo ip netns exec "$peer" ip link set peer0 up
  sudo ip netns exec "$peer" ip link set lo up
done
sudo install -d /srv/training-http
printf 'healthy-service\n' | sudo tee /srv/training-http/index.html >/dev/null
for port in 8080 8081; do
  sudo tee "/etc/systemd/system/training-http-$port.service" >/dev/null <<UNIT
[Unit]
Description=HTTP control for the host firewall lab
After=network.target
[Service]
ExecStart=/usr/bin/python3 -m http.server $port --bind 0.0.0.0 --directory /srv/training-http
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT
done
sudo systemctl daemon-reload
sudo systemctl enable --now training-http-8080 training-http-8081
sudo nft add table inet training
sudo nft 'add chain inet training input { type filter hook input priority 0; policy accept; }'

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import subprocess, sys
def run(args):
    return subprocess.run(args,text=True,capture_output=True,timeout=10)
def request(peer,network,port):
    return run(['ip','netns','exec',peer,'curl','--noproxy','*','--connect-timeout','2','--max-time','3','-fsS',f'http://{network}.1:{port}/'])
def check(outcome):
    for port in (8080,8081):
        control=run(['curl','--noproxy','*','--max-time','3','-fsS',f'http://127.0.0.1:{port}/'])
        assert control.returncode==0 and control.stdout.strip()=='healthy-service', 'Keep both host services healthy'
    for peer,network in [('trusted','192.0.2'),('untrusted','198.51.100')]:
        if run(['ip','netns','exec',peer,'ping','-c','1','-W','2',network+'.1']).returncode:
            raise RuntimeError('Preserve peer addressing and ICMP reachability: '+peer)
    allowed=request('trusted','192.0.2',8080)
    assert allowed.returncode==0 and allowed.stdout.strip()=='healthy-service', 'Permit the trusted client on port 8080'
    blocked=request('untrusted','198.51.100',8080)
    if outcome=='source-boundary':
        assert blocked.returncode!=0, 'Reject the untrusted client on port 8080'
        if blocked.returncode not in (7,28): raise RuntimeError('Unexpected client failure: '+blocked.stderr)
    elif outcome=='port-boundary':
        for peer,network in [('trusted','192.0.2'),('untrusted','198.51.100')]:
            public=request(peer,network,8081)
            assert public.returncode==0 and public.stdout.strip()=='healthy-service', 'Keep public port 8081 reachable from both peers'
        # This outcome also requires the restriction to exist; an unchanged
        # bootstrap must not earn points for preserving the public service.
        assert blocked.returncode in (7,28), 'Restrict port 8080 without blocking public port 8081'
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
