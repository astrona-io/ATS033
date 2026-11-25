#!/usr/bin/env bash
# Prints a JSON array of labs and playgrounds for a GitHub Actions matrix:
#   [{"kind":"lab","path":"sections/.../labs/lab-01"},
#    {"kind":"playground","path":"sections/.../playground"}, ...]
#
#   list-environments.sh                        # every section
#   list-environments.sh sections/section-040   # only these paths
#   list-environments.sh --changed-since <ref>  # environments changed since <ref>
#
# With --changed-since, only the labs and playgrounds with a changed file in
# their own directory are selected: every environment is self-contained, so
# a change in one cannot break another. The shared lab files in
# scripts/ci/lab-files are copied into each lab, so a change there also
# changes the labs that use it. A change to scripts/ci/test-playground.sh
# selects every playground, and nothing else. Changes to the workflow, other
# CI scripts, course pages, quizzes and astrona.yaml select nothing; the
# weekly run and a manual run test every section. No match prints [].
set -euo pipefail
cd "$(dirname "$0")/../.."

paths=()
if [ "${1:-}" = "--changed-since" ]; then
  ref=${2:?usage: list-environments.sh --changed-since <ref>}
  changed=$(git diff --name-only "$ref"...HEAD)
  # A deleted lab or playground has no directory left, so it is skipped.
  while read -r environment; do
    [ -d "$environment" ] && paths+=("$environment")
  done < <(
    {
      grep -oE '^sections/section-[0-9]+/module-[0-9]+/(labs/lab-[0-9]+|playground)/' <<<"$changed" || true
      if grep -qx 'scripts/ci/test-playground.sh' <<<"$changed"; then
        find sections -type d -path '*/module-*/playground'
      fi
    } | sed 's|/$||' | sort -u
  )
  [ "${#paths[@]}" -gt 0 ] || { echo '[]'; exit 0; }
elif [ "$#" -gt 0 ]; then
  paths=("$@")
else
  paths=(sections)
fi

find "${paths[@]}" -name config.yaml \( -path '*/labs/lab-*/config.yaml' -o -path '*/playground/config.yaml' \) |
  sort |
  while read -r config; do
    dir=$(dirname "$config")
    case "$dir" in
      */playground) kind=playground ;;
      *) kind=lab ;;
    esac
    runtime=$(sed -n 's/^  type: //p' "$config" | head -n 1 | tr -d '"')
    runtime=${runtime:-kind}
    case "$runtime" in kind|qemu) ;; *) echo "Unsupported runtime: $runtime" >&2; exit 1 ;; esac
    printf '{"kind":"%s","path":"%s","runtime":"%s"}\n' "$kind" "$dir" "$runtime"
  done |
  jq -cs .
