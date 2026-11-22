#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach inside
# the playground VM, in page order, and fails when one of them does not give
# the result the page shows or describes.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user. The VM is the only node, so
# node commands use sudo directly, as on the pages.
set -euo pipefail
cluster="astro-ats-033-playground-040-03"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
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
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"
audit_log=/var/log/audit/audit.log

# Write the code block that follows "Save this as `<file>`", "Save it as
# `<file>`" or "Save this <words> as `<file>`" on a page into the work directory.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save (?:this|it)[^`\n]*? as `' + re.escape(name) + r'`.*?```[a-z]*\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the profile that the page shows before "save the profile above as
# `<file>`": the last code block before that sentence that defines
# `profile <file>`. The profile name and the file name are the same here.
save_file_above_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
position = text.find('above as `' + name + '`')
blocks = [block for block in re.findall(r'```[a-z]*\n(.*?)```', text[:position], re.S)
          if 'profile ' + name + ' ' in block] if position >= 0 else []
if not blocks:
    sys.exit('no code block above ' + name + ' in ' + page)
open(target, 'w').write(blocks[-1])
PY
}

# Write the YAML block from a page and apply it.
save_from_page() {
  save_file_from_page "$1" "$2"
  kubectl apply -f "$2"
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

# Run a command that the page expects to fail, keep its output in
# $failure_output and fail the smoke test when the command succeeds.
failure_output=''
expect_failure() {
  local description="$1"
  shift
  checks=$((checks + 1))
  printf 'check: %s\n' "$description"
  if failure_output="$("$@" 2>&1)"; then
    printf 'FAIL: %s\nthe command succeeded: %s\n' "$description" "$failure_output" >&2
    exit 1
  fi
  printf '%s\n' "$failure_output"
}

# Print the last audit message of a profile, with the pipeline of the page.
# auditd writes the message shortly after the access, so wait at most 10
# seconds for a line that names the file.
last_audit_message() {
  local profile_name="$1" file_name="$2" message='' attempt
  for attempt in $(seq 1 10); do
    message="$(sudo grep "profile=\"$profile_name\"" "$audit_log" | grep -o 'apparmor="[A-Z]*".*name="[^"]*"' | tail -1 || true)"
    [[ "$message" == *"name=\"$file_name\""* ]] && break
    sleep 1
  done
  printf '%s\n' "$message"
}

# Print the mode of a loaded profile from the kernel list, as the page does.
profile_mode() {
  sudo grep "$1" /sys/kernel/security/apparmor/profiles
}

# Guided Practice: Drop Capabilities And Block Escalation
page=playground/docs/overview.md
expect_equal 'guide: the context names the playground cluster' "$(kubectl config current-context)" "kubernetes-admin@$cluster"
pods="$(kubectl -n starfleet get pods)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c ' Running ' || true)" 2
expect_match 'guide: the shuttle Pod is Running' "$pods" '^shuttle +1/1 +Running '
expect_equal 'guide: no hardened workload exists yet' "$(printf '%s\n' "$pods" | grep -c '^bind-only ' || true)" 0
expect 'guide: apply creates bind-only' "$(save_from_page "$page" pod-bind-only.yaml)" 'pod/bind-only created'
expect 'guide: bind-only becomes Ready' "$(kubectl -n starfleet wait --for=condition=Ready pod/bind-only --timeout=180s)" 'pod/bind-only condition met'
expect_equal 'guide: the process runs as user 1000' "$(kubectl -n starfleet exec bind-only -- id -u)" 1000
status_lines="$(kubectl -n starfleet exec bind-only -- grep -E 'Seccomp:|NoNewPrivs|CapBnd' /proc/1/status)"
printf '%s\n' "$status_lines"
expect_match 'guide: CapBnd holds only NET_BIND_SERVICE' "$status_lines" '^CapBnd:[[:space:]]+0000000000000400$'
expect_match 'guide: NoNewPrivs is 1' "$status_lines" '^NoNewPrivs:[[:space:]]+1$'
expect_match 'guide: Seccomp is 2' "$status_lines" '^Seccomp:[[:space:]]+2$'

# AppArmor Modes And Loading Profiles
page=course-01-apparmor-modes-and-loading-profiles.md
expect_equal 'AppArmor is active in the kernel' "$(cat /sys/module/apparmor/parameters/enabled)" Y
expect_equal 'the node has apparmor_parser' "$(which apparmor_parser)" /usr/sbin/apparmor_parser
save_file_above_from_page "$page" k8s-deny-tmp-write
expect_equal 'copying the profile prints nothing' "$(sudo cp k8s-deny-tmp-write /etc/apparmor.d/k8s-deny-tmp-write 2>&1)" ''
expect_equal 'loading the profile prints nothing' "$(sudo apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write 2>&1)" ''
expect_equal 'the profile is loaded in enforce mode' "$(profile_mode k8s-deny-tmp-write)" 'k8s-deny-tmp-write (enforce)'
expect_failure 'aa-exec touch under the profile fails' aa-exec -p k8s-deny-tmp-write -- touch /tmp/apparmor-test
expect 'the kernel refuses the write under /tmp' "$failure_output" "touch: cannot touch '/tmp/apparmor-test': Permission denied"
expect 'aa-complain switches the profile' "$(sudo aa-complain /etc/apparmor.d/k8s-deny-tmp-write)" 'Setting /etc/apparmor.d/k8s-deny-tmp-write to complain mode.'
expect_equal 'the profile is in complain mode' "$(profile_mode k8s-deny-tmp-write)" 'k8s-deny-tmp-write (complain)'
expect_failure 'the deny rule still blocks in complain mode' aa-exec -p k8s-deny-tmp-write -- touch /tmp/apparmor-test
expect 'the write still fails with Permission denied' "$failure_output" "touch: cannot touch '/tmp/apparmor-test': Permission denied"
save_file_from_page "$page" k8s-write-tmp-only
# The page writes new files under /etc; remove them first so a second run of
# this script sees the same create operations as the first one.
sudo rm -f /etc/apparmor-test /etc/apparmor-test2
sudo cp k8s-write-tmp-only /etc/apparmor.d/k8s-write-tmp-only
sudo apparmor_parser -r -C /etc/apparmor.d/k8s-write-tmp-only
sudo aa-exec -p k8s-write-tmp-only -- touch /etc/apparmor-test
complain_message="$(last_audit_message k8s-write-tmp-only /etc/apparmor-test)"
expect 'complain mode logs the write as ALLOWED' "$complain_message" 'apparmor="ALLOWED"'
expect 'the ALLOWED message names /etc/apparmor-test' "$complain_message" 'profile="k8s-write-tmp-only" name="/etc/apparmor-test"'
expect 'aa-enforce switches the allow-list profile' "$(sudo aa-enforce /etc/apparmor.d/k8s-write-tmp-only)" 'Setting /etc/apparmor.d/k8s-write-tmp-only to enforce mode.'
expect_failure 'enforce mode blocks the write under /etc' sudo aa-exec -p k8s-write-tmp-only -- touch /etc/apparmor-test2
expect 'the write fails with Permission denied' "$failure_output" "touch: cannot touch '/etc/apparmor-test2': Permission denied"
enforce_message="$(last_audit_message k8s-write-tmp-only /etc/apparmor-test2)"
expect 'enforce mode logs the write as DENIED' "$enforce_message" 'apparmor="DENIED"'
expect 'the DENIED message names /etc/apparmor-test2' "$enforce_message" 'profile="k8s-write-tmp-only" name="/etc/apparmor-test2"'
expect 'k8s-deny-tmp-write goes back to enforce mode' "$(sudo aa-enforce /etc/apparmor.d/k8s-deny-tmp-write)" 'Setting /etc/apparmor.d/k8s-deny-tmp-write to enforce mode.'

# Select A Profile With appArmorProfile
page=course-02-select-a-profile-with-apparmorprofile.md
save_file_from_page "$page" k8s-deny-tmp-write
sudo cp k8s-deny-tmp-write /etc/apparmor.d/k8s-deny-tmp-write
sudo apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
expect_equal 'the profile is loaded in enforce mode' "$(profile_mode k8s-deny-tmp-write)" 'k8s-deny-tmp-write (enforce)'
save_from_page "$page" pod-apparmor-container.yaml
kubectl -n starfleet wait --for=condition=Ready pod/apparmor-two --timeout=120s
expect_equal 'general runs under the containerd default profile' "$(kubectl -n starfleet exec apparmor-two -c general -- cat /proc/1/attr/current)" 'cri-containerd.apparmor.d (enforce)'
expect_equal 'guarded runs under k8s-deny-tmp-write' "$(kubectl -n starfleet exec apparmor-two -c guarded -- cat /proc/1/attr/current)" 'k8s-deny-tmp-write (enforce)'
expect_equal 'the write in general succeeds and prints nothing' "$(kubectl -n starfleet exec apparmor-two -c general -- sh -c 'echo test > /tmp/file' 2>&1)" ''
expect_failure 'the write in guarded fails' kubectl -n starfleet exec apparmor-two -c guarded -- sh -c 'echo test > /tmp/file'
expect 'guarded prints Permission denied' "$failure_output" "sh: can't create /tmp/file: Permission denied"
kubectl -n starfleet delete pod apparmor-two
save_from_page "$page" pod-apparmor-missing.yaml
# The page checks after about ten seconds; wait at most 60 seconds for the error.
missing_state=''
for attempt in $(seq 1 30); do
  missing_state="$(kubectl -n starfleet get pod apparmor-missing)"
  [[ "$missing_state" == *CreateContainerError* ]] && break
  sleep 2
done
printf '%s\n' "$missing_state"
expect_match 'the status is CreateContainerError' "$missing_state" '^apparmor-missing +0/1 +CreateContainerError '
events="$(kubectl -n starfleet describe pod apparmor-missing | sed -n '/^Events:/,$p')"
printf '%s\n' "$events"
expect_match 'a kubelet Warning event reports the failure' "$events" 'Warning +Failed .*kubelet'
expect 'the event names the missing profile' "$events" 'apparmor profile not found k8s-not-loaded'
kubectl -n starfleet delete pod apparmor-missing

# Drop Capabilities And Block Privilege Escalation
page=course-03-drop-capabilities-and-block-privilege-escalation.md
save_from_page "$page" pods-capability-compare.yaml
kubectl -n starfleet wait --for=condition=Ready pod/caps-default pod/caps-none pod/caps-bind --timeout=120s
capabilities="$(for pod_name in caps-default caps-none caps-bind; do
  printf '%s\n' "$pod_name"
  kubectl -n starfleet exec "$pod_name" -- grep -E 'CapBnd|CapEff|NoNewPrivs' /proc/1/status
done)"
printf '%s\n' "$capabilities"
# Keep the three lines of one pod: the pod name line and the lines below it.
pod_lines() { printf '%s\n' "$capabilities" | sed -n "/^$1\$/,/^NoNewPrivs/p"; }
expect_match 'caps-default keeps the runtime default set' "$(pod_lines caps-default)" '^CapEff:[[:space:]]+00000000a80425fb$'
expect_match 'caps-default bounding set is the default set' "$(pod_lines caps-default)" '^CapBnd:[[:space:]]+00000000a80425fb$'
expect_match 'caps-default allows escalation' "$(pod_lines caps-default)" '^NoNewPrivs:[[:space:]]+0$'
expect_match 'caps-none has an empty effective set' "$(pod_lines caps-none)" '^CapEff:[[:space:]]+0000000000000000$'
expect_match 'caps-none has an empty bounding set' "$(pod_lines caps-none)" '^CapBnd:[[:space:]]+0000000000000000$'
expect_match 'caps-none blocks escalation' "$(pod_lines caps-none)" '^NoNewPrivs:[[:space:]]+1$'
expect_match 'caps-bind effective set is NET_BIND_SERVICE' "$(pod_lines caps-bind)" '^CapEff:[[:space:]]+0000000000000400$'
expect_match 'caps-bind bounding set is NET_BIND_SERVICE' "$(pod_lines caps-bind)" '^CapBnd:[[:space:]]+0000000000000400$'
expect_match 'caps-bind blocks escalation' "$(pod_lines caps-bind)" '^NoNewPrivs:[[:space:]]+1$'
expect_failure 'chown fails without CHOWN' kubectl -n starfleet exec caps-none -- sh -c 'touch /tmp/f && chown 1000 /tmp/f'
expect 'chown prints Operation not permitted' "$failure_output" 'chown: /tmp/f: Operation not permitted'
expect 'the shell exits with code 1' "$failure_output" 'command terminated with exit code 1'
expect_equal 'the same command succeeds in caps-default' "$(kubectl -n starfleet exec caps-default -- sh -c 'touch /tmp/f && chown 1000 /tmp/f' 2>&1)" ''
kubectl -n starfleet delete pod caps-default caps-none caps-bind

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
