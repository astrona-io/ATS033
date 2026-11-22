#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-033-playground-040-01
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-$playground}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-$playground}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"
# The playground has one node, the control plane. The pages name it
# $node_name and run node commands with podman; this script uses "$engine".
node_name="$cluster-control-plane"
run_on_node() { "$engine" exec "$node_name" "$@"; }

# Write the code block that follows "Save this as `<file>`" (or "Save it as
# `<file>`") on a page into the work directory.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save (?:this|it) as `' + re.escape(name) + r'`.*?```[a-z]*\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the YAML block from a page and apply it.
save_from_page() {
  save_file_from_page "$1" "$2"
  kubectl apply -f "$2"
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
    failures=$((failures + 1))
  fi
  printf '%s\n' "$failure_output"
}

# Guided Practice: Run With A Restricted Security Context
# The guide opens with the playground and describes the starting state, so it
# runs first.
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c ' Running ' || true)" 2
expect_match 'guide: the shuttle Pod is Running' "$pods" '^shuttle +1/1 +Running '
expect 'guide: the probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o yaml)" 'readyReplicas: 2'
expect 'guide: apply creates restricted-reader' "$(save_from_page "$page" pod-restricted-reader.yaml)" 'pod/restricted-reader created'
kubectl -n starfleet wait --for=condition=Ready pod/restricted-reader --timeout=180s
expect_equal 'guide: the reader runs as user 1000' "$(kubectl -n starfleet exec restricted-reader -- id -u)" 1000
expect_equal 'guide: the scratch write works' "$(kubectl -n starfleet exec restricted-reader -- sh -c 'printf allowed > /scratch/result; cat /scratch/result')" allowed
expect_failure 'guide: the root filesystem write fails' kubectl -n starfleet exec restricted-reader -- sh -c 'printf denied > /root-file'
expect 'guide: the write fails because the filesystem is read-only' "$failure_output" 'Read-only file system'
reader_status="$(kubectl -n starfleet exec restricted-reader -- cat /proc/1/status)"
expect_match 'guide: the reader reports Seccomp: 2' "$reader_status" '^Seccomp:[[:space:]]+2$'
expect_match 'guide: the reader reports NoNewPrivs: 1' "$reader_status" '^NoNewPrivs:[[:space:]]+1$'

# Seccomp: Filtering System Calls
page=course-01-seccomp-filtering-system-calls.md
save_from_page "$page" pods-seccomp-compare.yaml
kubectl -n starfleet wait --for=condition=Ready pod/seccomp-default pod/seccomp-unconfined --timeout=120s
default_status="$(kubectl -n starfleet exec seccomp-default -- grep -E 'Seccomp|NoNewPrivs' /proc/1/status)"
printf '%s\n' "$default_status"
expect_match 'the RuntimeDefault pod reports Seccomp: 2' "$default_status" '^Seccomp:[[:space:]]+2$'
expect_match 'the RuntimeDefault pod reports NoNewPrivs: 0' "$default_status" '^NoNewPrivs:[[:space:]]+0$'
unconfined_status="$(kubectl -n starfleet exec seccomp-unconfined -- grep -E 'Seccomp|NoNewPrivs' /proc/1/status)"
printf '%s\n' "$unconfined_status"
expect_match 'the Unconfined pod reports Seccomp: 0' "$unconfined_status" '^Seccomp:[[:space:]]+0$'
expect_match 'the Unconfined pod reports NoNewPrivs: 0' "$unconfined_status" '^NoNewPrivs:[[:space:]]+0$'
kubectl -n starfleet delete pod seccomp-default seccomp-unconfined
save_file_from_page "$page" block-mkdir.json
run_on_node mkdir -p /var/lib/kubelet/seccomp/profiles
"$engine" cp block-mkdir.json "$node_name:/var/lib/kubelet/seccomp/profiles/block-mkdir.json"
save_from_page "$page" pod-seccomp-localhost.yaml
kubectl -n starfleet wait --for=condition=Ready pod/seccomp-localhost --timeout=120s
expect_match 'the Localhost pod reports Seccomp: 2' "$(kubectl -n starfleet exec seccomp-localhost -- grep Seccomp /proc/1/status)" '^Seccomp:[[:space:]]+2$'
expect_failure 'mkdir fails under block-mkdir.json' kubectl -n starfleet exec seccomp-localhost -- mkdir /tmp/newdir
expect 'mkdir fails with Operation not permitted' "$failure_output" 'Operation not permitted'
expect_match 'the Localhost pod keeps running' "$(kubectl -n starfleet get pod seccomp-localhost)" '^seccomp-localhost +1/1 +Running '
kubectl -n starfleet delete pod seccomp-localhost

# AppArmor: Profiles For Files And Capabilities
page=course-02-apparmor-profiles-for-files-and-capabilities.md
# The page treats the rest of the part as reading material when the kernel of
# the machine that runs the node has no AppArmor, and says that apparmor_parser
# and aa-status may be missing in the node image. The script takes the same
# branch and prints which one it took.
apparmor_enabled="$(run_on_node cat /sys/module/apparmor/parameters/enabled 2>/dev/null || true)"
printf 'apparmor enabled: %s\n' "$apparmor_enabled"
aa_status_output="$(run_on_node aa-status 2>&1 || true)"
printf '%s\n' "$aa_status_output"
profile_loaded=no
if [[ "$apparmor_enabled" == Y ]]; then
  save_file_from_page "$page" k8s-deny-tmp-write
  if [[ "${GITHUB_ACTIONS:-}" == true ]] && ! run_on_node sh -c 'command -v apparmor_parser' >/dev/null 2>&1; then
    # CI only. The GitHub runner kernel has AppArmor, but the kind node image
    # is not ready to use it:
    # - it has no apparmor_parser, so the page's load commands cannot run;
    # - it has no securityfs at /sys/kernel/security, so the kubelet rejects
    #   the pod with "Cannot enforce AppArmor: AppArmor is not enabled on the
    #   host" (CI job 137359971123);
    # - containerd also needs apparmor_parser, or it fails the container with
    #   "failed to generate apparmor spec opts: apparmor is not supported"
    #   (CI job 137363165018).
    # The script installs the apparmor package in the node, mounts securityfs
    # and restarts containerd and the kubelet, which check AppArmor once at
    # start. After that the page's own commands run unchanged.
    run_on_node sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends apparmor >/dev/null'
    if ! run_on_node test -e /sys/kernel/security/apparmor; then
      run_on_node mount -t securityfs securityfs /sys/kernel/security
    fi
    run_on_node systemctl restart containerd
    run_on_node systemctl restart kubelet
    kubectl wait --for=condition=Ready "node/$node_name" --timeout=120s
    printf 'note: CI installed apparmor_parser in the node and mounted securityfs\n'
  fi
  if run_on_node sh -c 'command -v apparmor_parser' >/dev/null 2>&1; then
    # The page's commands: copy the profile into the node and load it.
    "$engine" cp k8s-deny-tmp-write "$node_name:/etc/apparmor.d/k8s-deny-tmp-write"
    run_on_node apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
    profile_loaded=yes
  fi
fi
if [[ "$profile_loaded" == yes ]]; then
  save_from_page "$page" pod-apparmor-localhost.yaml
  kubectl -n starfleet wait --for=condition=Ready pod/apparmor-localhost --timeout=120s
  attr_current="$(kubectl -n starfleet exec apparmor-localhost -- cat /proc/1/attr/current)"
  printf '%s\n' "$attr_current"
  expect_match 'the pod runs under k8s-deny-tmp-write followed by its mode in parentheses' "$attr_current" '^k8s-deny-tmp-write \([a-z]+\)$'
  expect_failure 'the /tmp write fails under the profile' kubectl -n starfleet exec apparmor-localhost -- sh -c 'echo test > /tmp/file'
  expect 'the /tmp write fails with Permission denied' "$failure_output" 'Permission denied'
  kubectl -n starfleet delete pod apparmor-localhost --timeout=120s
else
  printf 'note: AppArmor is not usable on this node (enabled=%s, no apparmor_parser in the node), so the page is reading material here\n' "${apparmor_enabled:-missing}"
fi

# The Restricted Security Context
page=course-03-the-restricted-security-context.md
# The guide created the same Pod from the same YAML. Live CI (job 137300299383)
# printed "configured" for the second apply, so the check accepts both answers.
expect_match 'apply keeps restricted-reader' "$(save_from_page "$page" pod-restricted-reader.yaml)" '^pod/restricted-reader (unchanged|configured)$'
kubectl -n starfleet wait --for=condition=Ready pod/restricted-reader --timeout=180s
expect_equal 'the user ID is 1000' "$(kubectl -n starfleet exec restricted-reader -- id -u)" 1000
expect_equal 'the scratch write prints allowed' "$(kubectl -n starfleet exec restricted-reader -- sh -c 'printf allowed > /scratch/result; cat /scratch/result')" allowed
status_lines="$(kubectl -n starfleet exec restricted-reader -- grep -E 'Seccomp|NoNewPrivs|CapEff' /proc/1/status)"
printf '%s\n' "$status_lines"
expect_match 'status shows Seccomp: 2' "$status_lines" '^Seccomp:[[:space:]]+2$'
expect_match 'status shows NoNewPrivs: 1' "$status_lines" '^NoNewPrivs:[[:space:]]+1$'
expect_match 'status shows CapEff made of zeros' "$status_lines" '^CapEff:[[:space:]]+0+$'
expect_failure 'the root filesystem write fails' kubectl -n starfleet exec restricted-reader -- sh -c 'printf denied > /root-file'
expect 'the error says the filesystem is read-only' "$failure_output" 'Read-only file system'
dry_run="$(kubectl label --dry-run=server --overwrite namespace starfleet pod-security.kubernetes.io/enforce=restricted 2>&1)"
printf '%s\n' "$dry_run"
expect 'the dry run warns about pods that violate restricted' "$dry_run" 'violate the new PodSecurity enforce level "restricted'
expect_match 'the dry run names a probe pod' "$dry_run" '^Warning: probe-'
expect 'the dry run does not change the namespace' "$dry_run" '(server dry run)'
expect_equal 'the namespace has no enforce label' "$(kubectl get namespace starfleet -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" ''

# Diagnosing Profile Failures
page=course-04-diagnosing-profile-failures.md
save_from_page "$page" pod-seccomp-missing.yaml
# The kubelet reports the error after its first attempt; wait at most 60 seconds.
missing_state=''
for attempt in $(seq 1 30); do
  missing_state="$(kubectl -n starfleet get pod seccomp-missing)"
  [[ "$missing_state" == *Error* ]] && break
  sleep 2
done
printf '%s\n' "$missing_state"
expect_match 'the pod shows an error state such as CreateContainerError' "$missing_state" '^seccomp-missing +0/1 +[A-Za-z]*Error '
description="$(kubectl -n starfleet describe pod seccomp-missing)"
printf '%s\n' "$description" | sed -n '/^Events:/,$p'
expect_match 'describe shows a warning event from the kubelet' "$description" 'Warning +[A-Za-z]+ .*kubelet'
expect 'the event names the missing profile file' "$description" 'does-not-exist.json'
kubectl -n starfleet delete pod seccomp-missing
override="$(kubectl -n starfleet get pod restricted-reader -o jsonpath='{.spec.securityContext.seccompProfile}{"\n"}{.spec.containers[0].securityContext.seccompProfile}{"\n"}')"
printf '%s\n' "$override"
expect_equal 'pod level is RuntimeDefault and the container line is empty' "$override" '{"type":"RuntimeDefault"}'

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
