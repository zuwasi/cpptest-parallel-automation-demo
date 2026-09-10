#!/usr/bin/env bash
set -euo pipefail

project=${1:?Usage: run-analysis-linux.sh project-alpha|project-beta|project-gamma}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cpptest_home=${CPPTEST_HOME:-/home/danie/parasoft/cpptest}
output_root=${OUTPUT_ROOT:-/tmp/xsightlab-automation}
compiler_family=${CPPTEST_COMPILER_FAMILY:-gcc_13-64}
run_dir="$output_root/$project"

case "$project" in
    project-alpha) config='MISRA C 2023 (MISRA C 2012).properties' ;;
    project-beta) config='Flow Analysis Standard.properties' ;;
    project-gamma) config='SEI CERT C Rules.properties' ;;
    *) echo "Unknown project: $project" >&2; exit 2 ;;
esac

rm -rf "$run_dir"
mkdir -p "$run_dir/build" "$run_dir/workspace" "$run_dir/report"

cmake -S "$root/$project" -B "$run_dir/build" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_C_COMPILER=/usr/bin/gcc
cmake --build "$run_dir/build" --clean-first

echo "ANALYSIS_START project=$project timestamp=$(date +%s.%N) pid=$$"
set +e
"$cpptest_home/cpptestcli" \
    -data "$run_dir/workspace" \
    -J-Xmx1024m \
    -config "$cpptest_home/configs/builtin/$config" \
    -bdf "$run_dir/build/compile_commands.json" \
    -report "$run_dir/report" \
    -property "bdf.import.compiler.family=$compiler_family" \
    -property bdf.import.c.compiler.exec=/usr/bin/gcc \
    -property bdf.import.cpp.compiler.exec=/usr/bin/g++ \
    -property bdf.import.linker.exec=/usr/bin/gcc \
    -property report.dtp.publish=false \
    -property console.verbosity.level=high
exit_code=$?
set -e
echo "ANALYSIS_END project=$project timestamp=$(date +%s.%N) exitCode=$exit_code"
exit "$exit_code"
