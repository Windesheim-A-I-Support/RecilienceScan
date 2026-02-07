"""
Logs Routes

Retrieve run logs for troubleshooting.
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse
from pathlib import Path
import logging

logger = logging.getLogger(__name__)
router = APIRouter(tags=["logs"])

LOGS_DIR = Path("/logs/runs")


@router.get("/logs/{run_id}")
async def get_run_logs(run_id: str):
    """
    Retrieve logs for a specific run.
    
    Args:
        run_id: UUID of the run
        
    Returns:
        Plain text log content
    """
    log_file = LOGS_DIR / f"{run_id}.log"
    
    if not log_file.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Logs not found for run {run_id}"
        )
    
    try:
        log_content = log_file.read_text()
        return PlainTextResponse(content=log_content)
    except Exception as e:
        logger.error(f"[ERROR] Failed to read logs: {e}")
        raise HTTPException(status_code=500, detail="Failed to read logs")
