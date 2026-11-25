#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-033-playground-040-02
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

# Copy block-rename.json into the kubelet seccomp directory of the node, with
# the two commands of the guide and of the second part.
copy_profile_to_node() {
  run_on_node mkdir -p /var/lib/kubelet/seccomp/profiles
  "$engine" cp block-rename.json "$node_name:/var/lib/kubelet/seccomp/profiles/block-rename.json"
}

# Guided Practice: Apply A Localhost seccomp Profile
# The guide opens with the playground and describes the starting state, so it
# runs first.
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c ' Running ' || true)" 2
expect_match 'guide: the shuttle Pod is Running' "$pods" '^shuttle +1/1 +Running '
# "No custom profile exists yet": the directory is empty or does not exist.
seccomp_listing="$(run_on_node ls /var/lib/kubelet/seccomp 2>&1 || true)"
printf '%s\n' "$seccomp_listing"
expect_equal 'guide: no custom profile exists yet' "$(printf '%s\n' "$seccomp_listing" | grep -c 'profiles' || true)" 0
save_file_from_page "$page" block-rename.json
copy_profile_to_node
expect 'guide: apply creates no-rename' "$(save_from_page "$page" pod-seccomp-block-rename.yaml)" 'pod/no-rename created'
kubectl -n starfleet wait --for=condition=Ready pod/no-rename --timeout=180s
expect_match 'guide: no-rename reports Seccomp: 2' "$(kubectl -n starfleet exec no-rename -- grep Seccomp: /proc/1/status)" '^Seccomp:[[:space:]]+2$'
expect_equal 'guide: creating and copying a file works' "$(kubectl -n starfleet exec no-rename -- sh -c 'echo data > /tmp/a && cp /tmp/a /tmp/b && cat /tmp/b')" data
expect_failure 'guide: mv fails under block-rename.json' kubectl -n starfleet exec no-rename -- mv /tmp/a /tmp/c
expect 'guide: mv fails with Operation not permitted' "$failure_output" 'Operation not permitted'
expect_match 'guide: no-rename keeps running' "$(kubectl -n starfleet get pod no-rename)" '^no-rename +1/1 +Running '

# Profile Types, Locations And The Unconfined Risk
page=course-010-profile-types-locations-and-the-unconfined-risk.md
seccomp_default="$(run_on_node grep -i seccompDefault /var/lib/kubelet/config.yaml || true)"
printf 'kubelet seccompDefault: %s\n' "$seccomp_default"
if [[ "$seccomp_default" == *true* ]]; then unset_mode=2; else unset_mode=0; fi
save_from_page "$page" pods-seccomp-types.yaml
kubectl -n starfleet wait --for=condition=Ready pod/seccomp-runtime pod/seccomp-unset pod/seccomp-privileged --timeout=120s
modes="$(for pod_name in seccomp-runtime seccomp-unset seccomp-privileged; do
  printf '%s: ' "$pod_name"
  kubectl -n starfleet exec "$pod_name" -- grep Seccomp: /proc/1/status
done)"
printf '%s\n' "$modes"
expect_match 'seccomp-runtime reports 2' "$modes" '^seccomp-runtime: Seccomp:[[:space:]]+2$'
expect_match "seccomp-unset follows the node default and reports $unset_mode" "$modes" "^seccomp-unset: Seccomp:[[:space:]]+$unset_mode\$"
expect_match 'seccomp-privileged reports 0' "$modes" '^seccomp-privileged: Seccomp:[[:space:]]+0$'
expect_equal 'the stored profile of seccomp-unset is empty' "$(kubectl -n starfleet get pod seccomp-unset -o jsonpath='{.spec.securityContext.seccompProfile}{"\n"}')" ''
kubectl -n starfleet delete pod seccomp-runtime seccomp-unset seccomp-privileged

# Write And Load A Localhost Profile
page=course-020-write-and-load-a-localhost-profile.md
save_file_from_page "$page" block-rename.json
copy_profile_to_node
profile_listing="$(run_on_node ls -l /var/lib/kubelet/seccomp/profiles)"
printf '%s\n' "$profile_listing"
expect_match 'the listing shows block-rename.json' "$profile_listing" ' block-rename\.json$'
# The guide created the same Pod from the same YAML, so apply leaves it as it is.
expect 'apply leaves no-rename unchanged' "$(save_from_page "$page" pod-seccomp-block-rename.yaml)" 'pod/no-rename unchanged'
kubectl -n starfleet wait --for=condition=Ready pod/no-rename --timeout=120s
expect_match 'the status shows Seccomp: 2' "$(kubectl -n starfleet exec no-rename -- grep Seccomp: /proc/1/status)" '^Seccomp:[[:space:]]+2$'
expect_equal 'the copy succeeds' "$(kubectl -n starfleet exec no-rename -- sh -c 'echo data > /tmp/a && cp /tmp/a /tmp/b && cat /tmp/b')" data
expect_failure 'mv fails under the profile' kubectl -n starfleet exec no-rename -- mv /tmp/a /tmp/c
expect 'mv fails with Operation not permitted' "$failure_output" 'Operation not permitted'
expect_match 'the pod stays Running' "$(kubectl -n starfleet get pod no-rename)" '^no-rename +1/1 +Running '
kubectl -n starfleet delete pod no-rename

# Find Blocked Syscalls And Fix Failures
page=course-030-find-blocked-syscalls-and-fix-failures.md
save_from_page "$page" pod-seccomp-typo.yaml
# The kubelet reports the error after its first attempt; wait at most 60 seconds.
typo_state=''
for attempt in $(seq 1 30); do
  typo_state="$(kubectl -n starfleet get pod seccomp-typo)"
  [[ "$typo_state" == *Error* ]] && break
  sleep 2
done
printf '%s\n' "$typo_state"
expect_match 'the pod does not become Running' "$typo_state" '^seccomp-typo +0/1 +[A-Za-z]*Error '
description="$(kubectl -n starfleet describe pod seccomp-typo)"
printf '%s\n' "$description" | sed -n '/^Events:/,$p'
expect_match 'describe shows a warning event from the kubelet' "$description" 'Warning +[A-Za-z]+ .*kubelet'
expect 'the event names the profile file it could not use' "$description" 'block-renam.json'
profiles="$(run_on_node ls /var/lib/kubelet/seccomp/profiles)"
printf '%s\n' "$profiles"
expect_equal 'the node has block-rename.json, not block-renam.json' "$profiles" block-rename.json
kubectl -n starfleet delete pod seccomp-typo
# log-all.json is shown for reading: the page uses it only on a test pod and
# does not apply it.

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
