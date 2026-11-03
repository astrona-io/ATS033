node='astro-ats-033-playground-010-02-control-plane'
ssh_text = command(['podman','exec',node,'sh','-c','cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config']).stdout
effective = {}
for line in ssh_text.splitlines():
    fields = line.split(None, 1)
    if len(fields) == 2 and not fields[0].startswith('#') and fields[0].lower() != 'include':
        effective.setdefault(fields[0].lower(), fields[1].strip())
assert effective.get('permitrootlogin') == 'no', 'Root login over SSH must be refused'
assert effective.get('passwordauthentication') == 'no', 'Password logins must be refused by the first value sshd reads'
assert effective.get('pubkeyauthentication') == 'yes', 'Key logins must stay on'
assert effective.get('allowusers') == 'opsadmin', 'Only opsadmin may log in'
old_user = command(['podman','exec',node,'getent','passwd','olduser']).stdout.strip().split(':')
assert old_user[6] == '/usr/sbin/nologin', 'Give olduser a shell that refuses logins'
assert command(['podman','exec',node,'passwd','-S','olduser']).stdout.split()[1] == 'L', 'Lock the password of olduser'
ops_user = command(['podman','exec',node,'getent','passwd','opsadmin']).stdout.strip().split(':')
assert ops_user[6] == '/bin/bash', 'opsadmin must keep its login shell'
assert command(['podman','exec',node,'systemctl','is-active','kubelet']).stdout.strip() == 'active'
assert command(['podman','exec',node,'systemctl','is-active','containerd']).stdout.strip() == 'active'
