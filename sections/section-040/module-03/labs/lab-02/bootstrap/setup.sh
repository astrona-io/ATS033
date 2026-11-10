#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apparmor-utils python3
sudo test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
sudo install -d -m 0777 /srv/allowed /srv/protected
printf 'readable\n' | sudo tee /srv/protected/reference >/dev/null
sudo chmod 0644 /srv/protected/reference
sudo install -d /opt/astrona-apparmor
sudo tee /opt/astrona-apparmor/check.py >/dev/null <<'CHECKER'
import pathlib, subprocess, sys

def run(*args):
    return subprocess.run(args, text=True, capture_output=True, timeout=15)

def check():
    profiles = pathlib.Path('/sys/kernel/security/apparmor/profiles').read_text().splitlines()
    assert 'training-write-boundary (enforce)' in profiles, 'Load training-write-boundary in enforce mode'
    identity = run('aa-exec', '-p', 'training-write-boundary', '--', 'cat', '/proc/self/attr/current')
    if identity.returncode:
        raise RuntimeError(identity.stderr)
    assert identity.stdout.strip() == 'training-write-boundary (enforce)', 'The test process must use the loaded profile'
    # A fresh path prevents a previous submission from supplying the evidence.
    import uuid
    name = str(uuid.uuid4())
    allowed = '/srv/allowed/' + name
    blocked = '/srv/protected/' + name
    try:
        for directory in ('/srv/allowed', '/srv/protected'):
            assert pathlib.Path(directory).is_dir(), 'Preserve both test directories'
            assert pathlib.Path(directory).stat().st_mode & 0o777 == 0o777, 'Keep ordinary permissions at 0777'
        baseline = run('sh', '-c', 'printf baseline > "$1"', 'sh', blocked)
        if baseline.returncode:
            raise RuntimeError('Unconfined write failed: ' + baseline.stderr)
        pathlib.Path(blocked).unlink()
        result = run('aa-exec', '-p', 'training-write-boundary', '--', 'sh', '-c', 'printf allowed > "$1"', 'sh', allowed)
        assert result.returncode == 0 and pathlib.Path(allowed).read_text() == 'allowed', 'Confined writes in /srv/allowed must work'
        result = run('aa-exec', '-p', 'training-write-boundary', '--', 'sh', '-c', 'printf blocked > "$1"', 'sh', blocked)
        assert result.returncode != 0 and 'Permission denied' in result.stderr and not pathlib.Path(blocked).exists(), 'AppArmor must deny a fresh write in /srv/protected'
        read = run('aa-exec', '-p', 'training-write-boundary', '--', 'cat', '/srv/protected/reference')
        assert read.returncode == 0 and read.stdout == 'readable\n', 'Keep reads of the protected reference working'
    finally:
        pathlib.Path(allowed).unlink(missing_ok=True)
        pathlib.Path(blocked).unlink(missing_ok=True)

try:
    check()
except AssertionError as error:
    print('FAIL:', error); sys.exit(1)
except (OSError, RuntimeError, subprocess.SubprocessError) as error:
    print('ERROR:', error); sys.exit(2)
print('PASS: the enforcing profile denies writes while preserving reads and allowed writes')
CHECKER
