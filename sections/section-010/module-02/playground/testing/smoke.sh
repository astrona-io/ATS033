#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach
# inside the playground VM, and fails when one of them does not give the
# result the page shows or describes.
# scripts/ci/test-playground.sh copies the module pages, docs/ and testing/
# into the VM and runs this file there as the student user, the user the
# learner logs in as. The VM is the only node, so node commands use sudo
# directly. The `astrona ssh` line of each page is the login itself and is not
# repeated here.
set -euo pipefail
cluster="astro-ats-033-playground-010-02"
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# The cluster is ready and the workloads of the pages run.
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null

module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
cd "$work_directory"

# Print the text block that directly follows the sh block on a page that
# contains the given command: the output the page shows for that block. The
# optional third argument picks the n-th such block.
output_from_page() {
  python3 - "$module_directory/$1" "$2" "${3:-1}" <<'PY'
import re, sys
page, command, wanted = sys.argv[1], sys.argv[2], int(sys.argv[3])
text = open(page).read()
found = 0
for block in re.finditer(r'```sh\n((?:(?!```).)*)```\s*```text\n(.*?)```', text, re.S):
    if command in block.group(1):
        found += 1
        if found == wanted:
            print(block.group(2), end='')
            break
else:
    sys.exit('no output block after ' + command + ' in ' + page)
PY
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -Eq -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# The test login of the pages: it tries no method, so the daemon refuses it
# and lists the methods it offers. ssh exits 255 on a refused login.
test_login() {
  ssh -o BatchMode=yes -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$1@127.0.0.1" true 2>&1 || true
}

# The journal can write the refusal a moment after ssh returns, so read it
# again for up to 10 seconds.
refusals_in_journal() {
  local attempt journal=''
  for attempt in $(seq 1 10); do
    journal="$(sudo journalctl --unit=ssh.service --since=-1min --no-pager --grep=AllowUsers 2>&1 || true)"
    grep -q 'User olduser from 127.0.0.1 not allowed because not listed in AllowUsers' <<<"$journal" && break
    sleep 1
  done
  printf '%s\n' "$journal"
}

refusal_line="^[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{8} $cluster sshd\[[0-9]+\]: User olduser from 127\.0\.0\.1 not allowed because not listed in AllowUsers$"
password_status='[0-9]{4}-[0-9]{2}-[0-9]{2} 0 99999 7 -1$'

# Guided Practice: Harden SSH Access And Unused Accounts
page=playground/docs/overview.md
expect_equal 'guide: the context is the playground' "$(kubectl config current-context)" "$(output_from_page "$page" 'kubectl config current-context')"
expect_equal 'guide: root and password logins are allowed' "$(sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers) '; sudo grep -H . /etc/ssh/sshd_config.d/50-cloud-init.conf)" "$(output_from_page "$page" 'sudo sshd -T | grep')"
expect_equal 'guide: the allow list is written' "$(sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowUsers opsadmin student astrona" | sudo tee /etc/ssh/sshd_config.d/10-allow-users.conf)" "$(output_from_page "$page" 'sudo tee /etc/ssh/sshd_config.d/10-allow-users.conf')"
expect_equal 'guide: the reloaded settings' "$(sudo sshd -t; sudo systemctl reload ssh.service; sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|allowusers) ')" "$(output_from_page "$page" 'sudo sshd -t')"
page_lines="$(output_from_page "$page" 'olduser@127.0.0.1 true')"
expect_equal 'guide: the daemon offers only publickey to olduser' "$(test_login olduser)" "$(head -n 2 <<<"$page_lines")"
journal="$(refusals_in_journal)"
printf '%s\n' "$journal"
expect_match 'guide: the journal names the AllowUsers refusal' "$journal" "$refusal_line"
sudo usermod --shell /usr/sbin/nologin --lock olduser
sudo rm /home/olduser/.ssh/authorized_keys
page_lines="$(output_from_page "$page" 'getent passwd olduser')"
expect_equal 'guide: olduser has the nologin shell' "$(getent passwd olduser)" "$(head -n 1 <<<"$page_lines")"
expect_match 'guide: the olduser password is locked' "$(sudo passwd -S olduser)" "^olduser L $password_status"
expect_equal 'guide: the node services and the API server work' "$(systemctl is-active kubelet.service containerd.service ssh.service; kubectl get --raw=/readyz; echo)" "$(output_from_page "$page" 'systemctl is-active kubelet.service')"

# The module pages start from the seeded state again: root and password logins
# allowed, no allow list, and olduser with a shell, a password and a key. These
# steps are not on a page; they only undo the guide.
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo rm /etc/ssh/sshd_config.d/10-allow-users.conf
sudo sshd -t
sudo systemctl reload ssh.service
sudo usermod --shell /bin/bash --unlock olduser
ssh-keygen -q -t ed25519 -N '' -C olduser@old-laptop -f "$work_directory/olduser"
sudo install -o olduser -g olduser -m 0600 "$work_directory/olduser.pub" /home/olduser/.ssh/authorized_keys

# Read The sshd Settings
page=course-01-read-the-sshd-settings.md
expect_equal 'read: the context is the playground' "$(kubectl config current-context)" "$(output_from_page "$page" 'kubectl config current-context')"
expect_equal 'read: the main file without comments' "$(grep -n -v -E '^(#|$)' /etc/ssh/sshd_config)" "$(output_from_page "$page" "grep -n -v -E '^(#|\$)' /etc/ssh/sshd_config")"
listing="$(ls -l /etc/ssh/sshd_config.d/)"
printf '%s\n' "$listing"
expect_match 'read: two drop-in files' "$listing" '^total 8$'
expect_match 'read: 50-cloud-init.conf is root only' "$listing" '^-rw------- 1 root root 27 .* 50-cloud-init\.conf$'
expect_match 'read: 60-cloudimg-settings.conf is world readable' "$listing" '^-rw-r--r-- 1 root root 26 .* 60-cloudimg-settings\.conf$'
expect_equal 'read: no other drop-in file' "$(ls /etc/ssh/sshd_config.d/ | wc -l)" 2
page_lines="$(output_from_page "$page" 'ls -l /etc/ssh/sshd_config.d/')"
expect_equal 'read: the drop-in values' "$(sudo grep -H . /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf)" "$(tail -n 2 <<<"$page_lines")"
expect_equal 'read: the effective values' "$(sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication) ')" "$(output_from_page "$page" 'kbdinteractiveauthentication) ')"
expect_equal 'read: the daemon offers publickey and password' "$(test_login opsadmin)" "$(output_from_page "$page" 'opsadmin@127.0.0.1 true')"
expect_equal 'read: the files say no, the running daemon still offers password' "$(sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo sshd -T | grep -E '^(passwordauthentication|pubkeyauthentication) '
test_login opsadmin)" "$(output_from_page "$page" "sudo sed -i 's/^PasswordAuthentication")"
expect_equal 'read: after the reload the daemon offers only publickey' "$(sudo sshd -t; sudo systemctl reload ssh.service; test_login opsadmin)" "$(output_from_page "$page" 'sudo sshd -t')"

# Limit Who Can Log In
page=course-02-limit-who-can-log-in.md
expect_equal 'limit: the context is the playground' "$(kubectl config current-context)" "$(output_from_page "$page" 'kubectl config current-context')"
expect_equal 'limit: the lines of the main file' "$(grep -n -E '^(Include|PermitRootLogin|AllowUsers|Match)' /etc/ssh/sshd_config)" "$(output_from_page "$page" "grep -n -E '^(Include|PermitRootLogin|AllowUsers|Match)'")"
expect_equal 'limit: sed prints nothing' "$(sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config 2>&1)" ''
# The first sshd -T prints no allowusers line, so its grep exits 1.
expect_equal 'limit: an appended allow list applies to backup only' "$(sudo cp /etc/ssh/sshd_config /tmp/sshd_config.test
echo "AllowUsers opsadmin student astrona" | sudo tee -a /tmp/sshd_config.test
sudo sshd -T -f /tmp/sshd_config.test | grep '^allowusers' || true
sudo sshd -T -f /tmp/sshd_config.test -C user=backup | grep '^allowusers'
sudo rm /tmp/sshd_config.test)" "$(output_from_page "$page" 'sudo cp /etc/ssh/sshd_config /tmp/sshd_config.test')"
expect_equal 'limit: the allow list is written' "$(echo "AllowUsers opsadmin student astrona" | sudo tee /etc/ssh/sshd_config.d/10-allow-users.conf)" "$(output_from_page "$page" 'sudo tee /etc/ssh/sshd_config.d/10-allow-users.conf')"
expect_equal 'limit: the reloaded settings' "$(sudo sshd -t; sudo systemctl reload ssh.service; sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|allowusers) ')" "$(output_from_page "$page" 'sudo sshd -t')"
page_lines="$(output_from_page "$page" 'olduser@127.0.0.1 true')"
expect_equal 'limit: the client sees the same refusal for both accounts' "$(test_login student; test_login olduser)" "$(head -n 4 <<<"$page_lines")"
journal="$(refusals_in_journal)"
printf '%s\n' "$journal"
expect_match 'limit: the journal names the AllowUsers refusal of olduser' "$journal" "$refusal_line"
expect_equal 'limit: the journal has no refusal for student' "$(grep -c 'User student ' <<<"$journal" || true)" 0

# Login Shells And Unused Accounts
page=course-03-login-shells-and-unused-accounts.md
expect_equal 'accounts: the context is the playground' "$(kubectl config current-context)" "$(output_from_page "$page" 'kubectl config current-context')"
expect_equal 'accounts: seven accounts have a login shell' "$(getent passwd | awk -F: '$7 !~ /(nologin|false)$/ {print $1 ":" $3 ":" $7}')" "$(output_from_page "$page" 'getent passwd | awk')"
expect_equal 'accounts: only root has UID 0' "$(awk -F: '$3 == 0 {print $1}' /etc/passwd)" "$(output_from_page "$page" "awk -F: '\$3 == 0")"
expect_match 'accounts: olduser has a usable password' "$(sudo passwd -S olduser)" "^olduser P $password_status"
keys="$(sudo ls -l /home/olduser/.ssh)"
printf '%s\n' "$keys"
expect_match 'accounts: the .ssh directory holds one file' "$keys" '^total 4$'
expect_match 'accounts: olduser has an authorized_keys file' "$keys" '^-rw------- 1 olduser olduser 100 .* authorized_keys$'
expect_equal 'accounts: usermod prints nothing' "$(sudo usermod --shell /usr/sbin/nologin --lock olduser 2>&1)" ''
page_lines="$(output_from_page "$page" 'sudo su olduser -c true')"
expect_equal 'accounts: olduser has the nologin shell' "$(getent passwd olduser)" "$(sed -n 1p <<<"$page_lines")"
expect_match 'accounts: the olduser password is locked' "$(sudo passwd -S olduser)" "^olduser L $password_status"
expect_equal 'accounts: su starts nologin' "$(sudo su olduser -c true 2>&1 || true)" "$(sed -n 3p <<<"$page_lines")"
expect_equal 'accounts: the key is gone and the node works' "$(sudo rm /home/olduser/.ssh/authorized_keys; sudo ls -l /home/olduser/.ssh; systemctl is-active kubelet.service containerd.service ssh.service; kubectl get --raw=/readyz; echo)" "$(output_from_page "$page" 'sudo rm /home/olduser/.ssh/authorized_keys')"

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
