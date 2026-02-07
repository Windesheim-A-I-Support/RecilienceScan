"""
Runs API Routes
"""

from fastapi import APIRouter, Query, Depends
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

from app.web.run_tracker import list_runs, get_run

router = APIRouter(tags=["runs"])

class RunResponse(BaseModel):
    run_id: str
    type: str
    status: str
    company_name: Optional[str] = None
    duration: Optional[int] = None
    created_at: datetime
    updated_at: datetime

class RunsResponse(BaseModel):
    runs: List[RunResponse]
    count: int


@router.get("/runs", response_model=RunsResponse)
async def list_all_runs(
    limit: int = Query(default=50, ge=1, le=500),
    run_type: Optional[str] = Query(default=None, pattern="^(ingest|render)$"),
    offset: int = Query(default=0, ge=0),
    status: Optional[str] = Query(default=None, regex="^(completed|running|failed|pending)$")
):
    """
    List recent runs with optional filtering.

    Args:
        limit: Maximum number of runs to return (1-500)
        run_type: Optional filter by type (ingest or render)
        offset: Number of runs to skip for pagination
        status: Optional filter by status (completed, running, failed, pending)

    Returns:
        JSON array of run metadata with enhanced fields
    """
    runs = list_runs(limit=limit, run_type=run_type, offset=offset, status=status)

    # Transform runs to include duration and other metadata
    enriched_runs = []
    for run in runs:
        duration = None
        if run.get("end_time") and run.get("start_time"):
            duration = int((run["end_time"] - run["start_time"]).total_seconds())

        enriched_run = {
            "run_id": run["run_id"],
            "type": run["type"],
            "status": run["status"],
            "company_name": run.get("company_name"),
            "duration": duration,
            "created_at": run["created_at"],
            "updated_at": run["updated_at"]
        }
        enriched_runs.append(enriched_run)

    return {"runs": enriched_runs, "count": len(runs)}


@router.get("/runs/{run_id}", response_model=RunResponse)
async def get_run_details(run_id: str):
    """Get details for specific run"""
    run = get_run(run_id)
    if not run:
        return {"error": "Run not found"}, 404

    # Calculate duration if available
    duration = None
    if run.get("end_time") and run.get("start_time"):
        duration = int((run["end_time"] - run["start_time"]).total_seconds())

    return {
        "run_id": run["run_id"],
        "type": run["type"],
        "status": run["status"],
        "company_name": run.get("company_name"),
        "duration": duration,
        "created_at": run["created_at"],
        "updated_at": run["updated_at"]
    }
