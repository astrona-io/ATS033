#!/usr/bin/env bash
# Starts one playground, runs its smoke test, and always destroys it.
#
#   scripts/ci/test-playground.sh sections/section-040/module-10/playground
#
# 1. `astrona run` must finish: the bootstrap and every waitFor in config.yaml
#    pass.
# 2. A kind playground: if it has testing/smoke.sh, the script runs it on this
#    machine with KUBECONFIG set to the playground cluster. The smoke test runs
#    the commands the pages teach and exits non-zero when one of them does not
#    give the expected result.
# 3. A qemu playground (runtime.type: qemu in config.yaml): the cluster and
#    its kubeconfig file exist only inside the VM, so the script runs the
#    checks there, over ssh, as the student user the learner logs in as. It
#    runs validate.sh (the context guard and the readiness checks) and then
#    testing/smoke.sh, if present, which checks the start state that
#    docs/overview.md describes.
#
# The script uses its own kubeconfig file, so it never changes the current
# context of the machine it runs on.
set -euo pipefail

dir=${1:?usage: test-playground.sh <playground directory>}
dir=$(cd "$dir" && pwd)

# Reads one top-level field (metadata.name or runtime.type) of config.yaml.
# Without the Python yaml module, the first "  name:" or "  type:" line is
# that field, as in every config.yaml of this repository.
config_field() {
  local section=$1 key=$2
  if python3 -c 'import yaml' 2>/dev/null; then
    python3 -c 'import sys, yaml; print((yaml.safe_load(open(sys.argv[1])).get(sys.argv[2]) or {}).get(sys.argv[3], ""))' \
      "$dir/config.yaml" "$section" "$key"
  else
    sed -n "s/^  $key: *//p" "$dir/config.yaml" | head -n 1 | tr -d '"'
  fi
}

name=$(config_field metadata name)
[ -n "$name" ] || { echo "no metadata.name in $dir/config.yaml" >&2; exit 1; }
# A config.yaml without runtime.type starts a kind cluster.
runtime=$(config_field runtime type)
runtime=${runtime:-kind}
work=$(mktemp -d)
export KUBECONFIG="$work/kubeconfig-start"

cleanup() {
  status=$?
  if [ "$status" -ne 0 ] && [ -n "${DIAGNOSTICS_DIR:-}" ]; then
    astrona diagnose "$name" -o "$DIAGNOSTICS_DIR/$name" --accept-terms --headless || true
  fi
  astrona destroy "$name" --accept-terms --headless </dev/null >/dev/null 2>&1 || true
  rm -rf "$work"
  echo "destroyed $name"
  exit "$status"
}
trap cleanup EXIT

echo "::group::astrona run $name"
(cd "$dir" && astrona run -c . --headless --accept-terms --trust --keep-context --yes)
echo "::endgroup::"

if [ "$runtime" = qemu ]; then
  vm_name="astro-$name"
  # `astrona list -o json` prints the ssh command of each VM in "details",
  # for example "ssh student@127.0.0.1 -p 55982". `astrona ssh` cannot run a
  # command without a terminal, so the script calls ssh itself.
  ssh_port=$(astrona list -o json --accept-terms --headless 2>/dev/null |
    python3 -c '
import json, re, sys
for vm in json.load(sys.stdin):
    if vm["name"] == sys.argv[1]:
        print(re.search(r"-p (\d+)", vm["details"]).group(1))
' "$vm_name")
  ssh_key="$HOME/.astrona/qemu/$vm_name/id_ed25519"
  [ -n "$ssh_port" ] && [ -f "$ssh_key" ] || { echo "no ssh port or key for $vm_name" >&2; exit 1; }

  # Copies a script into the VM and runs it there as student. The script reads
  # /dev/null as stdin, so commands that read stdin when it is not a terminal
  # (ausearch, kubectl exec -i) do not swallow the rest of the script.
  run_in_vm() {
    local script=$1
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -o ConnectTimeout=20 -i "$ssh_key" -p "$ssh_port" student@127.0.0.1 \
      'script_file=$(mktemp); cat >"$script_file"; bash "$script_file" </dev/null; status=$?; rm -f "$script_file"; exit $status' \
      <"$script"
  }

  echo "::group::readiness check $name (inside $vm_name)"
  run_in_vm "$dir/validate.sh"
  echo "::endgroup::"
  if [ -f "$dir/testing/smoke.sh" ]; then
    echo "::group::smoke test $name (inside $vm_name)"
    run_in_vm "$dir/testing/smoke.sh"
    echo "::endgroup::"
  else
    echo "no testing/smoke.sh: only the start and the readiness checks were tested"
  fi
  echo "PASS $name"
  exit 0
fi

# In CI astrona can print a terms notice first, so take the path line only.
KUBECONFIG=$(astrona kubeconfig "$name" --accept-terms --headless 2>/dev/null | grep -m1 "/kubeconfig$")
[ -f "$KUBECONFIG" ] || { echo "no kubeconfig file for $name" >&2; exit 1; }
export KUBECONFIG
echo "cluster context: $(kubectl config current-context)"

if [ -x "$dir/testing/smoke.sh" ]; then
  echo "::group::smoke test $name"
  "$dir/testing/smoke.sh"
  echo "::endgroup::"
else
  echo "no testing/smoke.sh: only the start and the readiness checks were tested"
fi
echo "PASS $name"
