"""
File Upload Handler Module

Provides secure file upload validation and storage with
filename sanitization and extension whitelisting.
"""

import re
from pathlib import Path
from typing import Tuple
import logging

logger = logging.getLogger(__name__)

# Security constraints
ALLOWED_EXTENSIONS = {".xlsx", ".xls", ".csv", ".tsv"}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
DATA_DIR = Path("/data/incoming")


def validate_file(filename: str, content_length: int) -> Tuple[bool, str]:
    """
    Validate file extension and size.
    
    Args:
        filename: Original filename
        content_length: File size in bytes
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    # Check extension
    ext = Path(filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        return False, f"Invalid file type: {ext}. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
    
    # Check size
    if content_length > MAX_FILE_SIZE:
        return False, f"File too large: {content_length} bytes. Maximum: {MAX_FILE_SIZE}"
    
    return True, ""


def sanitize_filename(filename: str) -> str:
    """
    Sanitize filename to prevent path traversal and special character issues.
    
    Args:
        filename: Original filename
        
    Returns:
        Sanitized filename safe for filesystem
    """
    # Remove path components
    filename = Path(filename).name
    
    # Replace unsafe characters with underscore
    safe_name = re.sub(r'[^a-zA-Z0-9._-]', '_', filename)
    
    # Prevent hidden files
    if safe_name.startswith('.'):
        safe_name = 'file_' + safe_name
    
    # Ensure extension is preserved
    if not any(safe_name.endswith(ext) for ext in ALLOWED_EXTENSIONS):
        safe_name += '.csv'  # Default to CSV if no valid extension
    
    return safe_name


async def save_upload(filename: str, content: bytes) -> Tuple[str, Path]:
    """
    Save uploaded file to incoming directory.
    
    Args:
        filename: Original filename (will be sanitized)
        content: File content as bytes
        
    Returns:
        Tuple of (sanitized_filename, full_path)
    """
    # Sanitize filename
    safe_name = sanitize_filename(filename)
    
    # Ensure data directory exists
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    # Handle duplicate filenames
    dest = DATA_DIR / safe_name
    counter = 1
    while dest.exists():
        stem = Path(safe_name).stem
        ext = Path(safe_name).suffix
        dest = DATA_DIR / f"{stem}_{counter}{ext}"
        safe_name = dest.name
        counter += 1
    
    # Write file
    dest.write_bytes(content)
    
    logger.info(f"[OK] Saved upload: {safe_name} ({len(content)} bytes)")
    
    return safe_name, dest
