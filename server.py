from __future__ import annotations

import json
import re
import subprocess
import threading
import time
import xml.etree.ElementTree as ET
from copy import deepcopy
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent
DOCS = ROOT / "docs"
PORT = 8765

PROJECTS = {
    "project-alpha": {
        "name": "Flight Sensor Statistics",
        "standard": "MISRA C 2023",
        "config": "MISRA C 2023 (MISRA C 2012)",
        "accent": "cyan",
        "requirements": ["MISRA 15.6: compound statements", "MISRA 10.4: essential types", "MISRA 12.2: arithmetic range"],
        "expectedIssues": ["Missing braces", "Signed/unsigned conversion", "Narrow arithmetic accumulator"],
    },
    "project-beta": {
        "name": "Audit Text Processor",
        "standard": "Flow Analysis",
        "config": "Flow Analysis Standard",
        "accent": "amber",
        "requirements": ["No use before initialization", "Validate before dereference", "Close resources on every path"],
        "expectedIssues": ["Uninitialized variable", "Possible null dereference", "File resource leak"],
    },
    "project-gamma": {
        "name": "Network Command Queue",
        "standard": "CERT C",
        "config": "SEI CERT C Rules",
        "accent": "violet",
        "requirements": ["STR31-C: sufficient string storage", "INT32-C: prevent signed overflow", "ERR33-C: handle library errors"],
        "expectedIssues": ["Unbounded strcpy", "Signed integer overflow", "Unchecked library result"],
    },
}


def new_project_state(project_id: str) -> dict:
    state = deepcopy(PROJECTS[project_id])
    state.update(
        id=project_id,
        status="idle",
        startedAt=None,
        endedAt=None,
        elapsedSeconds=0,
        pid=None,
        license="waiting",
        filesTotal=0,
        filesChecked=0,
        linesChecked=0,
        rulesConfigured=0,
        rulesExecuted=None,
        findings=0,
        detectedIssues=[],
        reportUrl=None,
        exitCode=None,
        console=[f"[{project_id}] Ready. Configuration: {state['config']}"],
    )
    return state


lock = threading.Lock()
state = {
    "mode": "live",
    "running": False,
    "runStartedAt": None,
    "runEndedAt": None,
    "projects": {project_id: new_project_state(project_id) for project_id in PROJECTS},
}


def append_console(project_id: str, line: str) -> None:
    clean = re.sub(r"\x1b\[[0-9;]*m", "", line.rstrip())
    if not clean:
        return
    with lock:
        console = state["projects"][project_id]["console"]
        console.append(clean)
        del console[:-180]


def update_from_line(project_id: str, line: str) -> None:
    append_console(project_id, line)
    with lock:
        project = state["projects"][project_id]
        if "Activating Automation Compliance Edition" in line:
            project["license"] = "activating"
        elif "Automation feature: License is valid" in line:
            project["license"] = "valid"
        elif "No valid license" in line or "There is no license" in line:
            project["license"] = "failed"

        match = re.search(r"Source Files to Check:\s*(\d+)", line)
        if match:
            project["filesTotal"] = int(match.group(1))
        match = re.search(r"Files Checked:.*?(\d+)/(\d+)", line)
        if match:
            project["filesChecked"] = int(match.group(1))
            project["filesTotal"] = max(project["filesTotal"], int(match.group(2)))
        match = re.search(r"Static analysis.*?-\s*(\d+) rules enabled", line)
        if match:
            project["rulesExecuted"] = int(match.group(1))
        match = re.search(r"Violations Found:\s*(\d+)", line)
        if match:
            project["findings"] = int(match.group(1))


def parse_report(project_id: str) -> None:
    report = ROOT / "reports" / project_id / "report.xml"
    if not report.exists():
        return

    root = ET.parse(report).getroot()
    rules = []
    findings = 0
    for rule in root.findall(".//RulesList/Rule"):
        rules.append(rule)
        stats = rule.find("Stats")
        total = int(stats.get("total", "0")) if stats is not None else 0
        findings += total

    project_node = root.find(".//CodingStandards/Projects/Project")
    with lock:
        project = state["projects"][project_id]
        project["rulesConfigured"] = len(rules)
        project["findings"] = findings
        project["detectedIssues"] = [
            {"id": rule.get("id"), "description": rule.get("desc"), "severity": int(rule.get("sev", "5"))}
            for rule in rules
            if rule.find("Stats") is not None and int(rule.find("Stats").get("total", "0")) > 0
        ]
        if project_node is not None:
            project["filesChecked"] = max(
                int(project_node.get("checkedFiles", "0")),
                int(project_node.get("bdCheckedFiles", "0")),
            )
            project["filesTotal"] = int(project_node.get("totFiles", "0"))
            project["linesChecked"] = int(project_node.get("checkedLns", "0"))
        project["reportUrl"] = f"/reports/{project_id}/report.html"


def run_project(project_id: str) -> None:
    script = ROOT / "scripts" / "run-analysis.ps1"
    command = [
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script),
        "-Project",
        project_id,
    ]
    started = time.time()
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    with lock:
        project = state["projects"][project_id]
        project.update(status="running", startedAt=started, pid=process.pid, console=[])

    assert process.stdout is not None
    for line in process.stdout:
        update_from_line(project_id, line)
        with lock:
            state["projects"][project_id]["elapsedSeconds"] = round(time.time() - started, 1)

    exit_code = process.wait()
    parse_report(project_id)
    with lock:
        project = state["projects"][project_id]
        project["endedAt"] = time.time()
        project["elapsedSeconds"] = round(project["endedAt"] - started, 1)
        project["exitCode"] = exit_code
        project["status"] = "completed" if exit_code == 0 else "failed"


def run_all() -> None:
    with lock:
        state["running"] = True
        state["runStartedAt"] = time.time()
        state["runEndedAt"] = None
        state["projects"] = {project_id: new_project_state(project_id) for project_id in PROJECTS}

    threads = [threading.Thread(target=run_project, args=(project_id,), daemon=True) for project_id in PROJECTS]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    with lock:
        state["running"] = False
        state["runEndedAt"] = time.time()


class DashboardHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DOCS), **kwargs)

    def send_json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/status":
            with lock:
                payload = deepcopy(state)
            now = time.time()
            for project in payload["projects"].values():
                if project["status"] == "running" and project["startedAt"]:
                    project["elapsedSeconds"] = round(now - project["startedAt"], 1)
            self.send_json(payload)
            return
        if path.startswith("/reports/"):
            report = (ROOT / path.lstrip("/")).resolve()
            if ROOT.resolve() not in report.parents or not report.is_file():
                self.send_error(404)
                return
            body = report.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html" if report.suffix == ".html" else "application/octet-stream")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/run":
            self.send_error(404)
            return
        with lock:
            if state["running"]:
                self.send_json({"error": "A parallel scan is already running."}, 409)
                return
        threading.Thread(target=run_all, daemon=True).start()
        self.send_json({"started": True}, 202)

    def log_message(self, format: str, *args) -> None:
        print(f"[dashboard] {format % args}")


if __name__ == "__main__":
    print(f"C++test parallel dashboard: http://localhost:{PORT}")
    ThreadingHTTPServer(("127.0.0.1", PORT), DashboardHandler).serve_forever()
