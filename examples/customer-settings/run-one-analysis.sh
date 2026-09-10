#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 PROJECT_NAME SOURCE_ROOT SETTINGS_FILE" >&2
    exit 2
fi

project_name=$1
source_root=$(realpath "$2")
settings_file=$(realpath "$3")
cpptest_home=${CPPTEST_HOME:-/opt/parasoft/cpptest}
run_root=${RUN_ROOT:-/results}/$project_name
max_heap=${CPPTEST_MAX_HEAP:-16G}

if grep -Ev '^[[:space:]]*#' "$settings_file" | grep -Eq '<[A-Z][A-Z0-9_]*>'; then
    echo "Replace all placeholders in $settings_file before running C++test." >&2
    exit 2
fi

if [[ ! -f "$source_root/compile_commands_merged.json" ]]; then
    echo "Missing $source_root/compile_commands_merged.json" >&2
    exit 2
fi

rm -rf "$run_root/workspace" "$run_root/report"
mkdir -p "$run_root/workspace" "$run_root/report"
rm -f "$run_root/.cpptest_analysis_complete"

set +e
"$cpptest_home/cpptestcli" \
    "-J-Xmx$max_heap" \
    -settings "$settings_file" \
    -data "$run_root/workspace" \
    -module "$source_root" \
    -input "$source_root/compile_commands_merged.json" \
    -report "$run_root/report" \
    -fail
exit_code=$?
set -e

if [[ $exit_code -eq 137 ]]; then
    echo "C++test was terminated, possibly because the container ran out of memory." >&2
    exit 137
fi

echo "$exit_code" > "$run_root/.cpptest_analysis_complete"
exit "$exit_code"
