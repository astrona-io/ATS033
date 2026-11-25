#!/usr/bin/env bash
# Runs the commands that docs/overview.md and the module readings teach inside
# the playground VM and fails when one of them does not give the result the
# page shows. scripts/ci/test-playground.sh copies the pages, docs/ and
# testing/ into the VM and runs this file there as the student user. The VM is
# the only node, so node commands use sudo directly.
set -euo pipefail
cluster="astro-ats-033-playground-020-01"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# The cluster is ready and the workloads of the pages run.
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null
id training-reader >/dev/null

module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"
report_directory=/var/lib/training-identity

# Write the first code block after "Save this as `<file>`" on a page into the
# work directory. The sentence may hold inline code before the block.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save this as `' + re.escape(name) + r'`.*?```[a-z]*\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

checks=0
# A failed check is counted, and the script goes on, so one run shows every
# difference between a page and the live playground. It exits 1 at the end.
failures=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; failures=$((failures + 1)); }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; failures=$((failures + 1)); }
}

expect_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -Eq -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; failures=$((failures + 1)); }
}

# kubectl auth can-i prints yes or no; a no ends with status 1.
can_i() {
  kubectl auth can-i "$@" 2>/dev/null || true
}

# Run a command until its output contains the wanted text, at most 15 times
# one second apart, and print the last output. auditd writes records a moment
# after the event, and ausearch exits 1 while it finds none.
wait_for_output() {
  local wanted="$1" attempt output=''
  shift
  for attempt in $(seq 1 15); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" == *"$wanted"* ]] && break
    sleep 1
  done
  printf '%s\n' "$output"
}

# course-01: users, groups and file permissions.
page=course-010-users-groups-and-file-permissions.md
expect_equal "$page: training-reader starts in its own group only" \
  "$(id training-reader)" 'uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader)'
listing="$(ls -l "$report_directory")"
expect_match "$page: ls -l shows total 8" "$listing" '^total 8$'
expect_match "$page: private-report is -rw------- root root 26" "$listing" '^-rw------- 1 root root +26 .* private-report$'
expect_match "$page: public-report is -rw-r----- root training-readers 18" "$listing" '^-rw-r----- 1 root training-readers 18 .* public-report$'
expect "$page: public-report is denied before the group change" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/public-report" 2>&1 || true)" \
  'cat: /var/lib/training-identity/public-report: Permission denied'
sudo usermod --append --groups training-readers training-reader
expect_equal "$page: public-report is readable through the group" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/public-report")" 'disposable-report'
expect "$page: private-report is still denied" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/private-report" 2>&1 || true)" \
  'cat: /var/lib/training-identity/private-report: Permission denied'
expect_equal "$page: id shows the new group" \
  "$(id training-reader)" 'uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader),1003(training-readers)'
expect_equal "$page: getent group lists training-reader" \
  "$(getent group training-readers)" 'training-readers:x:1003:training-reader'

# course-02: privilege elevation, account locking and the SSH daemon.
page=course-020-privilege-elevation-and-account-locking.md
expect_equal "$page: visudo -c parses three files" "$(sudo visudo -c)" \
  "$(printf '%s\n' '/etc/sudoers: parsed OK' '/etc/sudoers.d/90-cloud-init-users: parsed OK' '/etc/sudoers.d/README: parsed OK')"
expect "$page: training-reader may not run sudo" "$(sudo -l -U training-reader)" \
  "User training-reader is not allowed to run sudo on $cluster."
expect "$page: student may run everything" "$(sudo -l -U student)" '(ALL) NOPASSWD: ALL'
expect_equal "$page: getent passwd shows the account" \
  "$(getent passwd training-reader)" 'training-reader:x:1003:1004::/home/training-reader:/bin/sh'
expect_match "$page: passwd -S shows a usable password" \
  "$(sudo passwd -S training-reader)" '^training-reader P [0-9-]+ 0 99999 7 -1$'
password_ageing="$(sudo chage -l training-reader)"
expect_match "$page: chage shows that the password never expires" "$password_ageing" '^Password expires[[:space:]]+: never$'
expect_match "$page: chage shows that the account never expires" "$password_ageing" '^Account expires[[:space:]]+: never$'
sudo usermod --lock --expiredate 1 --shell /usr/sbin/nologin training-reader
expect_match "$page: passwd -S shows the lock" \
  "$(sudo passwd -S training-reader)" '^training-reader L [0-9-]+ 0 99999 7 -1$'
locked_login="$(sudo su -s /bin/sh -c 'id -un' training-reader 2>&1 || true)"
expect "$page: su reports the expired account" "$locked_login" 'Your account has expired; please contact your system administrator.'
expect "$page: su fails" "$locked_login" 'su: Authentication failure'
sudo usermod --unlock --expiredate '' --shell /bin/sh training-reader
expect_match "$page: passwd -S shows the unlocked password" \
  "$(sudo passwd -S training-reader)" '^training-reader P [0-9-]+ 0 99999 7 -1$'
sshd_settings="$(sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries) ')"
expect_equal "$page: sshd -T shows the default settings" "$sshd_settings" \
  "$(printf '%s\n' 'maxauthtries 6' 'permitrootlogin without-password' 'passwordauthentication no' 'kbdinteractiveauthentication no')"
expect_equal "$page: sshd_config.d holds the two image files" "$(ls /etc/ssh/sshd_config.d)" \
  "$(printf '%s\n' 50-cloud-init.conf 60-cloudimg-settings.conf)"
expect_equal "$page: the Include line is line 12" \
  "$(grep -n -i include /etc/ssh/sshd_config)" '12:Include /etc/ssh/sshd_config.d/*.conf'
save_file_from_page "$page" 10-hardening.conf
sudo install -m 0644 10-hardening.conf /etc/ssh/sshd_config.d/10-hardening.conf
sudo sshd -t
sudo systemctl reload ssh
expect_equal "$page: sshd -T shows the hardened settings" \
  "$(sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|maxauthtries) ')" \
  "$(printf '%s\n' 'maxauthtries 3' 'permitrootlogin no' 'passwordauthentication no')"
expect "$page: a key-only login as training-reader is refused" \
  "$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null training-reader@127.0.0.1 true 2>&1 || true)" \
  'training-reader@127.0.0.1: Permission denied (publickey).'

# course-03: a ServiceAccount with one permission.
page=course-030-kubernetes-identities-and-rbac.md
save_file_from_page "$page" serviceaccount-probe-reader.yaml
save_file_from_page "$page" role-pod-reader.yaml
save_file_from_page "$page" rolebinding-probe-reader.yaml
expect_equal "$page: the three objects are created" \
  "$(kubectl apply -f serviceaccount-probe-reader.yaml -f role-pod-reader.yaml -f rolebinding-probe-reader.yaml)" \
  "$(printf '%s\n' serviceaccount/probe-reader\ created role.rbac.authorization.k8s.io/pod-reader\ created rolebinding.rbac.authorization.k8s.io/probe-reader-pod-reader\ created)"
sa=system:serviceaccount:starfleet:probe-reader
expect_equal "$page: probe-reader can list pods" "$(can_i list pods --as="$sa" -n starfleet)" yes
expect_equal "$page: probe-reader cannot delete pods" "$(can_i delete pods --as="$sa" -n starfleet)" no
expect_equal "$page: probe-reader cannot get secrets" "$(can_i get secrets --as="$sa" -n starfleet)" no
expect_equal "$page: probe-reader cannot list pods in outpost" "$(can_i list pods --as="$sa" -n outpost)" no
expect_match "$page: --list shows get and list on pods" \
  "$(kubectl auth can-i --list --as="$sa" -n starfleet)" '^pods +\[\] +\[\] +\[get list\]$'
save_file_from_page "$page" pod-sa-reader.yaml
kubectl apply -f pod-sa-reader.yaml
expect "$page: sa-reader becomes Ready" \
  "$(kubectl -n starfleet wait --for=condition=Ready pod/sa-reader --timeout=120s)" 'pod/sa-reader condition met'
expect "$page: sa-reader has no token directory" \
  "$(kubectl -n starfleet exec sa-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount 2>&1 || true)" \
  'ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory'
expect_equal "$page: the probe pods have the token directory" \
  "$(kubectl -n starfleet exec deploy/probe -- ls /var/run/secrets/kubernetes.io/serviceaccount)" \
  "$(printf '%s\n' ca.crt namespace token)"

# course-04: revoking host and Kubernetes access.
page=course-040-revoking-host-and-kubernetes-access.md
sudo usermod --append --groups training-readers training-reader
expect_equal "$page: the first read succeeds" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/public-report")" 'disposable-report'
expect_equal "$page: gpasswd removes the membership" \
  "$(sudo gpasswd --delete training-reader training-readers)" 'Removing user training-reader from group training-readers'
expect "$page: the second read is denied" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/public-report" 2>&1 || true)" \
  'cat: /var/lib/training-identity/public-report: Permission denied'
expect_equal "$page: id no longer shows training-readers" \
  "$(id training-reader)" 'uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader)'
expect_equal "$page: the group has no members" "$(getent group training-readers)" 'training-readers:x:1003:'
expect_equal "$page: the RoleBinding is deleted" \
  "$(kubectl -n starfleet delete rolebinding probe-reader-pod-reader)" \
  'rolebinding.rbac.authorization.k8s.io "probe-reader-pod-reader" deleted from starfleet namespace'
expect_equal "$page: probe-reader can no longer list pods" "$(can_i list pods --as="$sa" -n starfleet)" no
kubectl get rolebindings -A -o wide >/dev/null
cluster_bindings="$(kubectl get clusterrolebindings -o wide)"
expect_match "$page: cluster-admin is bound to system:masters" "$cluster_bindings" '^cluster-admin +ClusterRole/cluster-admin .*system:masters'
expect_match "$page: system:basic-user is bound to system:authenticated" "$cluster_bindings" '^system:basic-user +ClusterRole/system:basic-user .*system:authenticated'
expect_match "$page: system:public-info-viewer is bound to every caller" "$cluster_bindings" \
  '^system:public-info-viewer +ClusterRole/system:public-info-viewer .*system:authenticated, system:unauthenticated'

# course-05: audit trails on the node.
page=course-050-audit-trails-on-the-node-and-in-the-cluster.md
expect_match "$page: auth.log holds sudo COMMAND lines for student" \
  "$(sudo grep -E 'sudo:.*COMMAND' /var/log/auth.log | tail -n 3)" 'sudo: +student : PWD=.* ; USER=root ; COMMAND=/'
expect_match "$page: the ssh journal has sshd lines" \
  "$(sudo journalctl --unit ssh -n 4 --no-pager)" " $cluster sshd\[[0-9]+\]: "
expect_equal "$page: auditd has no rules yet" "$(sudo auditctl -l)" 'No rules'
sudo auditctl -w /etc/sudoers.d -p wa -k sudoers-change
echo '# test' | sudo tee /etc/sudoers.d/99-audit-test >/dev/null
audit_records="$(wait_for_output '99-audit-test using /usr/bin/tee' sudo ausearch --input-logs -k sudoers-change --format text)"
expect "$page: ausearch shows the new rule" "$audit_records" 'student, acting as root, successfully add_rule sudoers-change using /usr/sbin/auditctl'
expect "$page: ausearch names student for the root write" "$audit_records" \
  'student, acting as root, successfully opened-file /etc/sudoers.d/99-audit-test using /usr/bin/tee'
sudo rm /etc/sudoers.d/99-audit-test
sudo auditctl -W /etc/sudoers.d -p wa -k sudoers-change

# course-06: persistent audit rules with augenrules.
page=course-060-persistent-audit-rules-with-augenrules.md
expect_equal "$page: rules.d holds only audit.rules" "$(sudo ls /etc/audit/rules.d)" 'audit.rules'
expect_equal "$page: the default file holds four settings" \
  "$(sudo grep -v -e '^#' -e '^$' /etc/audit/rules.d/audit.rules)" \
  "$(printf '%s\n' -D '-b 8192' '--backlog_wait_time 60000' '-f 1')"
expect_equal "$page: tee prints the rule" \
  "$(echo '-w /etc/sudoers.d -p wa -k sudoers-change' | sudo tee /etc/audit/rules.d/40-sudoers.rules)" \
  '-w /etc/sudoers.d -p wa -k sudoers-change'
expect_equal "$page: augenrules --check reports a change" \
  "$(sudo augenrules --check 2>&1 || true)" '/usr/sbin/augenrules: Rules have changed and should be updated'
expect_equal "$page: the kernel has no rules before the load" "$(sudo auditctl -l)" 'No rules'
sudo augenrules --load >/dev/null
expect_equal "$page: the kernel has the rule after the load" "$(sudo auditctl -l)" '-w /etc/sudoers.d -p wa -k sudoers-change'
expect_equal "$page: the generated file has the rule" \
  "$(sudo grep sudoers /etc/audit/audit.rules)" '-w /etc/sudoers.d -p wa -k sudoers-change'
expect_equal "$page: augenrules --check reports no change" "$(sudo augenrules --check 2>&1 || true)" '/usr/sbin/augenrules: No change'
expect_equal "$page: tee prints the sudo rule" \
  "$(echo 'training-reader ALL=(root) NOPASSWD: /usr/bin/systemctl status kubelet' | sudo tee /etc/sudoers.d/40-training-reader)" \
  'training-reader ALL=(root) NOPASSWD: /usr/bin/systemctl status kubelet'
sudo chmod 0440 /etc/sudoers.d/40-training-reader
expect_equal "$page: visudo -c parses the new file" "$(sudo visudo -c)" \
  "$(printf '%s\n' '/etc/sudoers: parsed OK' '/etc/sudoers.d/40-training-reader: parsed OK' '/etc/sudoers.d/90-cloud-init-users: parsed OK' '/etc/sudoers.d/README: parsed OK')"
audit_records="$(wait_for_output 'changed-file-permissions-of' sudo ausearch --input-logs -k sudoers-change -f /etc/sudoers.d/40-training-reader --format text)"
expect "$page: ausearch shows the tee record" "$audit_records" \
  'student, acting as root, successfully opened-file /etc/sudoers.d/40-training-reader using /usr/bin/tee'
expect "$page: ausearch shows the chmod record" "$audit_records" \
  'student, acting as root, successfully changed-file-permissions-of /etc/sudoers.d/40-training-reader to 0440 using /usr/bin/chmod'
sudo auditctl -w /etc/ssh/sshd_config -p wa -k sshd-config
sudo systemctl restart auditd
expect_equal "$page: only the persistent rule survives the restart" "$(sudo auditctl -l)" '-w /etc/sudoers.d -p wa -k sudoers-change'
sudo rm /etc/sudoers.d/40-training-reader /etc/audit/rules.d/40-sudoers.rules
sudo augenrules --load >/dev/null
expect_equal "$page: no rules are left" "$(sudo auditctl -l)" 'No rules'

# docs/overview.md runs last: course-04 has put the account back out of the
# group, which is the start state the guide expects.
page=playground/docs/overview.md
expect_match "$page: the node is Ready" "$(kubectl get nodes)" "^$cluster +Ready +control-plane +[^ ]+ +v1\.35\.10$"
expect_equal "$page: training-reader starts in its own group only" \
  "$(id training-reader)" 'uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader)'
listing="$(sudo ls -l "$report_directory")"
expect_match "$page: private-report is -rw------- root root 26" "$listing" '^-rw------- 1 root root +26 .* private-report$'
expect_match "$page: public-report is -rw-r----- root training-readers 18" "$listing" '^-rw-r----- 1 root training-readers 18 .* public-report$'
expect "$page: public-report is denied before the group change" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/public-report" 2>&1 || true)" \
  'cat: /var/lib/training-identity/public-report: Permission denied'
sudo usermod --append --groups training-readers training-reader
expect_equal "$page: public-report is readable through the group" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/public-report")" 'disposable-report'
expect "$page: private-report is still denied" \
  "$(sudo runuser -u training-reader -- cat "$report_directory/private-report" 2>&1 || true)" \
  'cat: /var/lib/training-identity/private-report: Permission denied'
expect_equal "$page: id shows the new group" \
  "$(id training-reader)" 'uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader),1003(training-readers)'
save_file_from_page "$page" configmap-identity-review.yaml
expect_equal "$page: the ConfigMap is created" \
  "$(kubectl apply -f configmap-identity-review.yaml)" 'configmap/identity-review created'
expect_equal "$page: the ConfigMap holds the result" \
  "$(kubectl -n starfleet get configmap identity-review -o jsonpath='{.data}')" '{"identity":"training-reader","result":"scoped-read"}'

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'smoke: %s checks passed on %s\n' "$checks" "$cluster"
