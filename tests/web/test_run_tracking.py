"""
Unit tests for run tracking module
"""

import pytest
import json
from pathlib import Path
from app.web.run_tracker import create_run, update_run_status, get_run, list_runs, delete_run


def test_create_run(tmp_path, monkeypatch):
    """Test creating a new run"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    run_id = create_run("ingest", filename="test.csv")
    
    assert run_id is not None
    assert len(run_id) == 36  # UUID format
    
    run_file = tmp_path / f"{run_id}.json"
    assert run_file.exists()
    
    metadata = json.loads(run_file.read_text())
    assert metadata["run_id"] == run_id
    assert metadata["type"] == "ingest"
    assert metadata["status"] == "pending"
    assert metadata["filename"] == "test.csv"


def test_update_run_status(tmp_path, monkeypatch):
    """Test updating run status"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    run_id = create_run("render", company_name="TestCo")
    
    success = update_run_status(run_id, "running")
    assert success is True
    
    metadata = get_run(run_id)
    assert metadata["status"] == "running"
    
    success = update_run_status(run_id, "success", report_path="/reports/test.pdf")
    assert success is True
    
    metadata = get_run(run_id)
    assert metadata["status"] == "success"
    assert metadata["completed_at"] is not None
    assert metadata["report_path"] == "/reports/test.pdf"


def test_get_run(tmp_path, monkeypatch):
    """Test retrieving run metadata"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    run_id = create_run("ingest")
    
    metadata = get_run(run_id)
    assert metadata is not None
    assert metadata["run_id"] == run_id
    
    missing = get_run("nonexistent-id")
    assert missing is None


def test_list_runs(tmp_path, monkeypatch):
    """Test listing runs"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    # Create multiple runs
    run1 = create_run("ingest", filename="file1.csv")
    run2 = create_run("render", company_name="Company1")
    run3 = create_run("ingest", filename="file2.csv")
    
    # List all runs
    runs = list_runs()
    assert len(runs) == 3
    
    # Filter by type
    ingest_runs = list_runs(run_type="ingest")
    assert len(ingest_runs) == 2
    
    render_runs = list_runs(run_type="render")
    assert len(render_runs) == 1
    
    # Test limit
    limited = list_runs(limit=2)
    assert len(limited) == 2


def test_delete_run(tmp_path, monkeypatch):
    """Test deleting a run"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    run_id = create_run("ingest")
    
    run_file = tmp_path / f"{run_id}.json"
    assert run_file.exists()
    
    success = delete_run(run_id)
    assert success is True
    assert not run_file.exists()
    
    # Try deleting non-existent run
    success = delete_run("nonexistent")
    assert success is False


def test_run_status_transitions(tmp_path, monkeypatch):
    """Test status transitions from pending to completed"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    run_id = create_run("ingest", filename="test.csv")
    
    # pending -> running
    update_run_status(run_id, "running")
    assert get_run(run_id)["status"] == "running"
    assert get_run(run_id)["completed_at"] is None
    
    # running -> success
    update_run_status(run_id, "success", stats={"rows": 100})
    metadata = get_run(run_id)
    assert metadata["status"] == "success"
    assert metadata["completed_at"] is not None
    assert metadata["stats"]["rows"] == 100


def test_failed_run_with_error(tmp_path, monkeypatch):
    """Test failed run with error message"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    run_id = create_run("render", company_name="TestCo")
    update_run_status(run_id, "running")
    update_run_status(run_id, "failed", error="File not found")
    
    metadata = get_run(run_id)
    assert metadata["status"] == "failed"
    assert metadata["error"] == "File not found"
    assert metadata["completed_at"] is not None
