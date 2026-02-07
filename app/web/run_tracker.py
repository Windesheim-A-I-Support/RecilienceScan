"""
Run Tracking Module

Manages run metadata for ingestion and rendering pipeline executions.
Uses UUID-based identifiers and JSON storage in /logs/runs/.
"""

import json
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Run storage directory
RUNS_DIR = Path("/logs/runs")


def create_run(run_type: str, filename: Optional[str] = None, **kwargs) -> str:
    """
    Create a new run with unique UUID identifier.
    
    Args:
        run_type: Type of run ("ingest" or "render")
        filename: Optional filename associated with the run
        **kwargs: Additional metadata to store
        
    Returns:
        run_id: Unique UUID string for this run
    """
    run_id = str(uuid.uuid4())
    
    metadata = {
        "run_id": run_id,
        "type": run_type,
        "status": "pending",
        "filename": filename,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
        "completed_at": None,
        "error": None,
        **kwargs
    }
    
    # Ensure runs directory exists
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Write run metadata
    run_file = RUNS_DIR / f"{run_id}.json"
    run_file.write_text(json.dumps(metadata, indent=2))
    
    logger.info(f"[INFO] Created run {run_id} (type: {run_type})")
    
    return run_id


def update_run_status(run_id: str, status: str, error: Optional[str] = None, **kwargs) -> bool:
    """
    Update the status of an existing run.
    
    Args:
        run_id: UUID of the run to update
        status: New status ("pending", "running", "success", "failed")
        error: Optional error message if status is "failed"
        **kwargs: Additional fields to update
        
    Returns:
        bool: True if update successful, False if run not found
    """
    run_file = RUNS_DIR / f"{run_id}.json"
    
    if not run_file.exists():
        logger.error(f"[ERROR] Run {run_id} not found")
        return False
    
    # Load existing metadata
    metadata = json.loads(run_file.read_text())
    
    # Update fields
    metadata["status"] = status
    metadata["updated_at"] = datetime.utcnow().isoformat()
    
    if error:
        metadata["error"] = error
    
    if status in ("success", "failed"):
        metadata["completed_at"] = datetime.utcnow().isoformat()
    
    # Merge additional fields
    metadata.update(kwargs)
    
    # Write updated metadata
    run_file.write_text(json.dumps(metadata, indent=2))
    
    logger.info(f"[OK] Updated run {run_id} status to {status}")
    
    return True


def get_run(run_id: str) -> Optional[Dict]:
    """
    Retrieve metadata for a specific run.
    
    Args:
        run_id: UUID of the run to retrieve
        
    Returns:
        Dict with run metadata, or None if not found
    """
    run_file = RUNS_DIR / f"{run_id}.json"
    
    if not run_file.exists():
        return None
    
    return json.loads(run_file.read_text())


def list_runs(limit: Optional[int] = 50, run_type: Optional[str] = None) -> List[Dict]:
    """
    List recent runs, sorted by creation time (newest first).
    
    Args:
        limit: Maximum number of runs to return (default 50)
        run_type: Optional filter by run type ("ingest" or "render")
        
    Returns:
        List of run metadata dictionaries
    """
    if not RUNS_DIR.exists():
        return []
    
    # Get all run files
    run_files = list(RUNS_DIR.glob("*.json"))
    
    # Load metadata and sort by creation time
    runs = []
    for run_file in run_files:
        try:
            metadata = json.loads(run_file.read_text())
            
            # Filter by type if specified
            if run_type and metadata.get("type") != run_type:
                continue
            
            runs.append(metadata)
        except (json.JSONDecodeError, KeyError) as e:
            logger.warning(f"[WARN] Skipping invalid run file {run_file.name}: {e}")
            continue
    
    # Sort by created_at (newest first)
    runs.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    
    # Apply limit
    if limit:
        runs = runs[:limit]
    
    return runs


def delete_run(run_id: str) -> bool:
    """
    Delete a run's metadata file.
    
    Args:
        run_id: UUID of the run to delete
        
    Returns:
        bool: True if deleted, False if not found
    """
    run_file = RUNS_DIR / f"{run_id}.json"
    
    if not run_file.exists():
        return False
    
    run_file.unlink()
    logger.info(f"[OK] Deleted run {run_id}")
    
    return True
