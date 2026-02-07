"""
Runs API Routes
"""

from fastapi import APIRouter, Query
from typing import Optional

from app.web.run_tracker import list_runs, get_run

router = APIRouter(tags=["runs"])


@router.get("/runs")
async def list_all_runs(
    limit: int = Query(default=50, ge=1, le=500),
    run_type: Optional[str] = Query(default=None, pattern="^(ingest|render)$")
):
    """
    List recent runs with optional filtering.
    
    Args:
        limit: Maximum number of runs to return (1-500)
        run_type: Optional filter by type (ingest or render)
        
    Returns:
        JSON array of run metadata
    """
    runs = list_runs(limit=limit, run_type=run_type)
    return {"runs": runs, "count": len(runs)}


@router.get("/runs/{run_id}")
async def get_run_details(run_id: str):
    """Get details for specific run"""
    run = get_run(run_id)
    if not run:
        return {"error": "Run not found"}, 404
    return run
