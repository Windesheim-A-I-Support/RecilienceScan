"""
File Upload Routes

Handles file uploads with validation and sanitization.
"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from pathlib import Path
import logging

from app.web.file_handler import validate_file, save_upload

logger = logging.getLogger(__name__)
router = APIRouter(tags=["upload"])


@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """
    Upload a data file (xlsx/csv/tsv) to the incoming directory.
    
    Args:
        file: Uploaded file from multipart form data
        
    Returns:
        JSON with upload confirmation
    """
    try:
        # Read file content
        content = await file.read()
        
        # Validate
        is_valid, error_msg = validate_file(file.filename, len(content))
        if not is_valid:
            logger.error(f"[ERROR] Upload validation failed: {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)
        
        # Save
        safe_name, full_path = await save_upload(file.filename, content)
        
        logger.info(f"[OK] File uploaded: {safe_name}")
        
        return {
            "status": "success",
            "filename": safe_name,
            "original_filename": file.filename,
            "size": len(content),
            "path": str(full_path)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[ERROR] Upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
