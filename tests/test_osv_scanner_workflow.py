"""
Additional OSV scanner workflow unit tests.

Testing framework: pytest
"""

import json
import subprocess
from pathlib import Path
import pytest

from src.ci.osv_scanner_workflow import run_osv_scan, parse_scan_output

class DummyCompletedProcess:
    def __init__(self, returncode=0, stdout=b"", stderr=b""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr

def test_run_osv_scan_success(monkeypatch, tmp_path):
    """Arrange: stub subprocess.run for a successful scan
       Act: invoke run_osv_scan
       Assert: report file is created with correct JSON payload"""
    payload = {"results": [{"vulnerabilities": []}]}
    def fake_run(cmd, capture_output, check):
        assert "--json" in cmd
        return DummyCompletedProcess(stdout=json.dumps(payload).encode())
    monkeypatch.setattr(subprocess, "run", fake_run)
    target = tmp_path / "dummy"
    report = tmp_path / "report.json"
    target.mkdir()
    run_osv_scan(target, report)
    assert report.exists()
    assert json.loads(report.read_text()) == payload

def test_run_osv_scan_cli_failure(monkeypatch, tmp_path):
    """Arrange: stub subprocess.run to simulate CLI failure
       Act & Assert: RuntimeError is raised on non-zero exit"""
    def fake_run(cmd, capture_output, check):
        return DummyCompletedProcess(returncode=1, stderr=b"boom")
    monkeypatch.setattr(subprocess, "run", fake_run)
    with pytest.raises(RuntimeError):
        run_osv_scan(tmp_path, tmp_path / "r.json")

def test_parse_scan_output_detects_vulns():
    """Arrange: prepare JSON with one vulnerability
       Act: call parse_scan_output
       Assert: list contains expected vuln dict"""
    payload = {"results": [{"vulnerabilities": [{"id": "CVE-123"}]}]}
    vulns = parse_scan_output(json.dumps(payload).encode())
    assert len(vulns) == 1
    assert vulns[0]["id"] == "CVE-123"

def test_parse_scan_output_no_vulns():
    """Arrange: prepare JSON with empty vuln lists
       Act & Assert: parser returns empty list"""
    payload = {"results": [{"vulnerabilities": []}]}
    assert parse_scan_output(json.dumps(payload).encode()) == []

def test_parse_scan_output_invalid_json():
    """Arrange: provide invalid JSON bytes
       Act & Assert: ValueError is raised"""
    with pytest.raises(ValueError):
        parse_scan_output(b"{ not-json }")

def test_parse_scan_output_empty_results():
    """Arrange: JSON with no results entries
       Act & Assert: empty list is returned"""
    assert parse_scan_output(b'{"results": []}') == []

@pytest.mark.parametrize("invalid_target", [
    Path("nonexistent_dir"),
    Path(__file__) / "unlikely"
])
def test_run_osv_scan_invalid_target_raises(invalid_target, tmp_path):
    """Arrange: define non-existent target path
       Act & Assert: FileNotFoundError is raised before scanning"""
    report = tmp_path / "report.json"
    with pytest.raises(FileNotFoundError):
        run_osv_scan(invalid_target, report)