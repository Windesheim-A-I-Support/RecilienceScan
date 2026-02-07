"""
Pipeline Execution Routes

Endpoints to trigger P2 ingestion and P3 rendering pipelines.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging

from app.web.pipeline_orchestrator import run_ingestion, run_rendering

logger = logging.getLogger(__name__)
router = APIRouter(tags=["pipeline"])


class IngestRequest(BaseModel):
    filename: Optional[str] = None


class RenderRequest(BaseModel):
    company_name: str
    person_name: Optional[str] = None
    output_format: str = "pdf"


@router.post("/run/ingest")
async def trigger_ingestion(request: IngestRequest = IngestRequest()):
    """
    Trigger P2 ingestion pipeline.
    
    Args:
        request: Optional filename to ingest (defaults to most recent)
        
    Returns:
        JSON with run status and ingestion statistics
    """
    try:
        result = await run_ingestion(request.filename)
        
        if result["status"] == "failed":
            raise HTTPException(status_code=500, detail=result.get("error", "Ingestion failed"))
        
        return result
        
    except HTTPException:
        raise
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"[ERROR] Ingestion trigger failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/run/render")
async def trigger_rendering(request: RenderRequest):
    """
    Trigger P3 rendering pipeline.
    
    Args:
        request: Rendering parameters (company_name required)
        
    Returns:
        JSON with run status and report path
    """
    if not request.company_name:
        raise HTTPException(status_code=400, detail="company_name is required")
    
    try:
        result = await run_rendering(
            request.company_name,
            request.person_name,
            request.output_format
        )
        
        if result["status"] == "failed":
            raise HTTPException(status_code=500, detail=result.get("error", "Rendering failed"))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[ERROR] Rendering trigger failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
