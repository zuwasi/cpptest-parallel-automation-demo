#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_root=${OUTPUT_ROOT:-/tmp/xsightlab-automation}
projects=(project-alpha project-beta project-gamma)
declare -A pids
failed=0

mkdir -p "$output_root"
for project in "${projects[@]}"; do
    OUTPUT_ROOT="$output_root" bash "$root/scripts/run-analysis-linux.sh" "$project" \
        >"$output_root/$project.log" 2>&1 &
    pids[$project]=$!
done

for project in "${projects[@]}"; do
    if ! wait "${pids[$project]}"; then
        failed=1
    fi
done

OUTPUT_ROOT="$output_root" python3 - <<'PY'
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

output_root = Path(os.environ["OUTPUT_ROOT"])
runs = []
for project in ("project-alpha", "project-beta", "project-gamma"):
    log = (output_root / f"{project}.log").read_text(errors="replace")
    start = re.search(rf"ANALYSIS_START project={project} timestamp=([0-9.]+)", log)
    end = re.search(rf"ANALYSIS_END project={project} timestamp=([0-9.]+) exitCode=(\d+)", log)
    if not start or not end:
        raise SystemExit(f"Missing scanner timestamps for {project}")
    if "Automation feature: License is valid" not in log:
        raise SystemExit(f"Automation license was not validated for {project}")

    report_path = output_root / project / "report" / "report.xml"
    report = ET.parse(report_path).getroot()
    project_node = report.find(".//CodingStandards/Projects/Project")
    rules = report.findall(".//RulesList/Rule")
    findings = sum(int(rule.find("Stats").get("total", "0")) for rule in rules if rule.find("Stats") is not None)
    runs.append({
        "project": project,
        "analysisStart": float(start.group(1)),
        "analysisEnd": float(end.group(1)),
        "durationSeconds": round(float(end.group(1)) - float(start.group(1)), 2),
        "exitCode": int(end.group(2)),
        "filesChecked": int(project_node.get("checkedFiles", "0")),
        "rulesInReport": len(rules),
        "findings": findings,
        "automationLicenseValid": True,
    })

result = {
    "allThreeAnalysesOverlapped": max(run["analysisStart"] for run in runs) < min(run["analysisEnd"] for run in runs),
    "runs": runs,
}
(output_root / "parallel-test-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
if not result["allThreeAnalysesOverlapped"] or any(run["exitCode"] for run in runs):
    sys.exit(1)
PY

exit "$failed"
