#!/usr/bin/env bash
# Grades the outcome this file is named after (validate-<outcome>.sh).
set -euo pipefail
outcome="$(basename "$0" .sh)"
exec bash "$(cd "$(dirname "$0")/.." && pwd)/validate.sh" "${outcome#validate-}"
