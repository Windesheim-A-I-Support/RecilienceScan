"""
Pipeline Orchestrator Module

Integrates with existing P2 ingestion and P3 rendering pipelines.
"""

from pathlib import Path
from typing import Dict, Optional
import logging

from app.web.run_tracker import create_run, update_run_status

logger = logging.getLogger(__name__)


async def run_ingestion(filename: Optional[str] = None) -> Dict:
    """
    Execute P2 ingestion pipeline.
    
    Args:
        filename: Optional specific file to ingest (defaults to most recent)
        
    Returns:
        Dict with run_id and ingestion results
    """
    # Create run
    run_id = create_run("ingest", filename=filename)
    
    try:
        update_run_status(run_id, "running")
        
        # Import P2 ingestion module
        from app.ingest import ingest_file
        
        # Determine file to ingest
        if not filename:
            # Find most recent file in /data/incoming/
            incoming_dir = Path("/data/incoming")
            files = sorted(incoming_dir.glob("*"), key=lambda f: f.stat().st_mtime, reverse=True)
            if not files:
                raise FileNotFoundError("No files found in /data/incoming/")
            filename = files[0].name
        
        # Execute ingestion
        logger.info(f"[INFO] Running ingestion for {filename}")
        file_path = Path("/data/incoming") / filename
        
        stats = ingest_file(str(file_path))
        
        # Mark success
        update_run_status(run_id, "success", stats=stats)
        
        logger.info(f"[OK] Ingestion complete: {run_id}")
        
        return {
            "run_id": run_id,
            "status": "success",
            "filename": filename,
            "stats": stats
        }
        
    except Exception as e:
        logger.error(f"[ERROR] Ingestion failed: {e}")
        update_run_status(run_id, "failed", error=str(e))
        
        return {
            "run_id": run_id,
            "status": "failed",
            "filename": filename,
            "error": str(e)
        }


async def run_rendering(company_name: str, person_name: Optional[str] = None, output_format: str = "pdf") -> Dict:
    """
    Execute P3 rendering pipeline.
    
    Args:
        company_name: Company name for report (required)
        person_name: Optional person name for report
        output_format: Output format (pdf or html)
        
    Returns:
        Dict with run_id and rendering results
    """
    # Create run
    run_id = create_run("render", company_name=company_name, person_name=person_name, output_format=output_format)
    
    try:
        update_run_status(run_id, "running")
        
        # Import P3 rendering module
        from generate_single_report import generate_single_report
        
        # Execute rendering
        logger.info(f"[INFO] Rendering report for {company_name}")
        
        report_path = generate_single_report(company_name, person_name, output_format)
        
        # Mark success
        update_run_status(run_id, "success", report_path=str(report_path))
        
        logger.info(f"[OK] Rendering complete: {run_id}")
        
        return {
            "run_id": run_id,
            "status": "success",
            "company_name": company_name,
            "report_path": str(report_path)
        }
        
    except Exception as e:
        logger.error(f"[ERROR] Rendering failed: {e}")
        update_run_status(run_id, "failed", error=str(e))
        
        return {
            "run_id": run_id,
            "status": "failed",
            "company_name": company_name,
            "error": str(e)
        }
