"""
Reports Routes

List and download generated reports.
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
import logging

logger = logging.getLogger(__name__)
router = APIRouter(tags=["reports"])

REPORTS_DIR = Path("/app/outputs")


@router.get("/reports")
async def list_reports():
    """List all available reports"""
    if not REPORTS_DIR.exists():
        return {"reports": [], "count": 0}
    
    reports = []
    for file_path in REPORTS_DIR.glob("*"):
        if file_path.suffix.lower() in [".pdf", ".html"]:
            reports.append({
                "filename": file_path.name,
                "size": file_path.stat().st_size,
                "modified": file_path.stat().st_mtime,
                "type": file_path.suffix[1:]
            })
    
    # Sort by modification time (newest first)
    reports.sort(key=lambda x: x["modified"], reverse=True)
    
    return {"reports": reports, "count": len(reports)}


@router.get("/reports/{filename:path}")
async def download_report(filename: str):
    """Download a specific report"""
    # Security: prevent path traversal
    safe_filename = Path(filename).name
    file_path = REPORTS_DIR / safe_filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Report not found")
    
    # Determine MIME type
    mime_type = "application/pdf" if file_path.suffix == ".pdf" else "text/html"
    
    return FileResponse(
        path=str(file_path),
        media_type=mime_type,
        filename=safe_filename
    )
