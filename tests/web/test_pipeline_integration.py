"""
Integration tests for pipeline orchestration
"""

import pytest
from unittest.mock import Mock, patch, AsyncMock
from app.web.pipeline_orchestrator import run_ingestion, run_rendering
from app.web.run_tracker import get_run


@pytest.mark.asyncio
@patch("app.web.pipeline_orchestrator.ingest_file")
async def test_run_ingestion_success(mock_ingest, tmp_path, monkeypatch):
    """Test successful ingestion pipeline execution"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    # Mock P2 ingestion
    mock_ingest.return_value = {"rows_loaded": 100, "rows_added": 50}
    
    # Create test file
    incoming_dir = tmp_path / "incoming"
    incoming_dir.mkdir(parents=True)
    test_file = incoming_dir / "test.csv"
    test_file.write_text("data")
    
    monkeypatch.setattr("app.web.pipeline_orchestrator.Path", lambda x: incoming_dir if "/data/incoming" in x else tmp_path / x)
    
    result = await run_ingestion("test.csv")
    
    assert result["status"] == "success"
    assert result["filename"] == "test.csv"
    assert "run_id" in result
    assert result["stats"]["rows_loaded"] == 100
    
    # Verify run metadata
    run = get_run(result["run_id"])
    assert run["status"] == "success"
    assert run["type"] == "ingest"


@pytest.mark.asyncio
@patch("app.web.pipeline_orchestrator.ingest_file")
async def test_run_ingestion_failure(mock_ingest, tmp_path, monkeypatch):
    """Test ingestion pipeline failure handling"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    # Mock P2 failure
    mock_ingest.side_effect = Exception("Database connection failed")
    
    incoming_dir = tmp_path / "incoming"
    incoming_dir.mkdir(parents=True)
    test_file = incoming_dir / "test.csv"
    test_file.write_text("data")
    
    monkeypatch.setattr("app.web.pipeline_orchestrator.Path", lambda x: incoming_dir if "/data/incoming" in x else tmp_path / x)
    
    result = await run_ingestion("test.csv")
    
    assert result["status"] == "failed"
    assert "Database connection failed" in result["error"]
    
    # Verify run metadata shows failure
    run = get_run(result["run_id"])
    assert run["status"] == "failed"
    assert run["error"] is not None


@pytest.mark.asyncio
@patch("app.web.pipeline_orchestrator.generate_single_report")
async def test_run_rendering_success(mock_render, tmp_path, monkeypatch):
    """Test successful rendering pipeline execution"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    # Mock P3 rendering
    mock_render.return_value = "/reports/TestCo_report.pdf"
    
    result = await run_rendering("TestCo", "John Doe", "pdf")
    
    assert result["status"] == "success"
    assert result["company_name"] == "TestCo"
    assert "run_id" in result
    assert result["report_path"] == "/reports/TestCo_report.pdf"
    
    # Verify run metadata
    run = get_run(result["run_id"])
    assert run["status"] == "success"
    assert run["type"] == "render"
    assert run["company_name"] == "TestCo"


@pytest.mark.asyncio
@patch("app.web.pipeline_orchestrator.generate_single_report")
async def test_run_rendering_failure(mock_render, tmp_path, monkeypatch):
    """Test rendering pipeline failure handling"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    # Mock P3 failure
    mock_render.side_effect = Exception("Company not found in database")
    
    result = await run_rendering("NonExistentCo")
    
    assert result["status"] == "failed"
    assert "Company not found" in result["error"]
    
    # Verify run metadata
    run = get_run(result["run_id"])
    assert run["status"] == "failed"


@pytest.mark.asyncio
async def test_run_ingestion_no_files(tmp_path, monkeypatch):
    """Test ingestion when no files exist in incoming directory"""
    monkeypatch.setattr("app.web.run_tracker.RUNS_DIR", tmp_path)
    
    incoming_dir = tmp_path / "incoming"
    incoming_dir.mkdir(parents=True)
    
    monkeypatch.setattr("app.web.pipeline_orchestrator.Path", lambda x: incoming_dir if "/data/incoming" in x else tmp_path / x)
    
    result = await run_ingestion()
    
    assert result["status"] == "failed"
    assert "No files found" in result["error"]
