assert command([ENGINE,'exec',NODE,'systemctl','is-active','kubelet']).stdout.strip() == 'active', 'The kubelet must stay active'
assert command([ENGINE,'exec',NODE,'systemctl','is-active','containerd']).stdout.strip() == 'active', 'containerd must stay active'
ops_user = command([ENGINE,'exec',NODE,'getent','passwd','opsadmin']).stdout.strip().split(':')
assert ops_user[6] == '/bin/bash', 'opsadmin must keep its login shell'
ssh_text = command([ENGINE,'exec',NODE,'sh','-c','cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config']).stdout
effective = {}
for line in ssh_text.splitlines():
    fields = line.split(None, 1)
    if len(fields) == 2 and not fields[0].startswith('#') and fields[0].lower() != 'include':
        effective.setdefault(fields[0].lower(), fields[1].strip())
if wants('root-login-refused'):
    assert effective.get('permitrootlogin') == 'no', 'Root login over SSH must be refused'
if wants('password-login-refused'):
    assert effective.get('passwordauthentication') == 'no', 'Password logins must be refused by the first value sshd reads'
    assert effective.get('pubkeyauthentication') == 'yes', 'Key logins must stay on'
if wants('allow-only-opsadmin'):
    assert effective.get('allowusers') == 'opsadmin', 'Only opsadmin may log in'
if wants('olduser-locked'):
    old_user = command([ENGINE,'exec',NODE,'getent','passwd','olduser']).stdout.strip().split(':')
    assert old_user[6] == '/usr/sbin/nologin', 'Give olduser a shell that refuses logins'
    assert command([ENGINE,'exec',NODE,'passwd','-S','olduser']).stdout.split()[1] == 'L', 'Lock the password of olduser'
