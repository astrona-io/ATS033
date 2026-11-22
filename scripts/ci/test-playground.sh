#!/usr/bin/env bash
# Starts one playground, runs its smoke test, and always destroys it.
#
#   scripts/ci/test-playground.sh sections/section-030/module-03/playground
#
# 1. `astrona run` must finish: the bootstrap and every waitFor in config.yaml
#    pass.
# 2. If the playground has testing/smoke.sh, it runs with KUBECONFIG set to
#    the playground cluster. The smoke test runs the commands the pages teach
#    and exits non-zero when one of them does not give the expected result.
#    A qemu playground has no kubeconfig on the host: its cluster lives inside
#    the VM. The script copies the module pages, docs/ and testing/ into the VM over
#    SSH, with the key and port of this playground, and runs smoke.sh there as
#    the student user, the user the learner logs in as.
#
# The script uses its own kubeconfig file, so it never changes the current
# context of the machine it runs on.
set -euo pipefail

dir=${1:?usage: test-playground.sh <playground directory>}
dir=$(cd "$dir" && pwd)
name=$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["metadata"]["name"])' "$dir/config.yaml")
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
(cd "$dir" && astrona run -c . --headless --accept-terms --trust --keep-context --yes) 2>&1 | tee "$work/run.log"
echo "::endgroup::"

runtime=$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["runtime"]["type"])' "$dir/config.yaml")
if [ "$runtime" = qemu ]; then
  if [ ! -x "$dir/testing/smoke.sh" ]; then
    echo "no testing/smoke.sh: only the start and the readiness checks were tested"
    echo "PASS $name"
    exit 0
  fi
  ssh_port=$(grep -o 'ssh-port=[0-9]*' "$work/run.log" | head -1 | cut -d= -f2)
  ssh_key="$HOME/.astrona/qemu/astro-$name/id_ed25519"
  [ -n "$ssh_port" ] && [ -f "$ssh_key" ] || { echo "no SSH port or key for $name" >&2; exit 1; }
  vm_ssh=(ssh -q -i "$ssh_key" -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes student@127.0.0.1)
  module=$(dirname "$dir")
  echo "::group::smoke test $name (inside the VM)"
  (cd "$module" && COPYFILE_DISABLE=1 tar -cf - --exclude labs ./*.md playground/docs playground/testing) | "${vm_ssh[@]}" 'rm -rf smoke && mkdir smoke && tar -xf - -C smoke'
  "${vm_ssh[@]}" 'bash smoke/playground/testing/smoke.sh' </dev/null
  echo "::endgroup::"
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
