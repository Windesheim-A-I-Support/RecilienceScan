"""
Unit tests for file upload validation and sanitization
"""

import pytest
from pathlib import Path
from app.web.file_handler import validate_file, sanitize_filename, save_upload


def test_validate_file_valid_extensions():
    """Test validation accepts valid file extensions"""
    assert validate_file("data.xlsx", 1000)[0] is True
    assert validate_file("data.xls", 1000)[0] is True
    assert validate_file("data.csv", 1000)[0] is True
    assert validate_file("data.tsv", 1000)[0] is True


def test_validate_file_invalid_extensions():
    """Test validation rejects invalid file extensions"""
    is_valid, error = validate_file("malicious.exe", 1000)
    assert is_valid is False
    assert "Invalid file type" in error
    
    is_valid, error = validate_file("script.sh", 1000)
    assert is_valid is False
    
    is_valid, error = validate_file("document.pdf", 1000)
    assert is_valid is False


def test_validate_file_size_limit():
    """Test validation enforces file size limit"""
    # Under limit
    assert validate_file("data.csv", 10 * 1024 * 1024)[0] is True
    
    # Over limit
    is_valid, error = validate_file("huge.csv", 100 * 1024 * 1024)
    assert is_valid is False
    assert "File too large" in error


def test_sanitize_filename_path_traversal():
    """Test filename sanitization prevents path traversal"""
    assert sanitize_filename("../../../etc/passwd") == "passwd.csv"
    assert sanitize_filename("../../data.csv") == "data.csv"
    assert sanitize_filename("/absolute/path/file.xlsx") == "file.xlsx"


def test_sanitize_filename_special_characters():
    """Test sanitization removes special characters"""
    assert sanitize_filename("file@#$%.csv") == "file____.csv"
    assert sanitize_filename("file with spaces.xlsx") == "file_with_spaces.xlsx"
    assert sanitize_filename("file\x00null.csv") == "file_null.csv"


def test_sanitize_filename_hidden_files():
    """Test sanitization prevents hidden files"""
    assert sanitize_filename(".hidden.csv").startswith("file_")
    assert not sanitize_filename("normal.csv").startswith(".")


def test_sanitize_filename_preserves_extension():
    """Test sanitization preserves valid extensions"""
    assert sanitize_filename("data.xlsx").endswith(".xlsx")
    assert sanitize_filename("report.csv").endswith(".csv")


@pytest.mark.asyncio
async def test_save_upload(tmp_path, monkeypatch):
    """Test file upload saves correctly"""
    monkeypatch.setattr("app.web.file_handler.DATA_DIR", tmp_path)
    
    content = b"test,data\n1,2\n3,4"
    safe_name, path = await save_upload("test.csv", content)
    
    assert safe_name == "test.csv"
    assert path.exists()
    assert path.read_bytes() == content


@pytest.mark.asyncio
async def test_save_upload_duplicate_handling(tmp_path, monkeypatch):
    """Test duplicate filename handling"""
    monkeypatch.setattr("app.web.file_handler.DATA_DIR", tmp_path)
    
    content1 = b"first"
    content2 = b"second"
    
    name1, path1 = await save_upload("data.csv", content1)
    name2, path2 = await save_upload("data.csv", content2)
    
    assert name1 == "data.csv"
    assert name2 == "data_1.csv"
    assert path1.read_bytes() == content1
    assert path2.read_bytes() == content2


@pytest.mark.asyncio
async def test_save_upload_sanitizes_filename(tmp_path, monkeypatch):
    """Test save_upload sanitizes malicious filenames"""
    monkeypatch.setattr("app.web.file_handler.DATA_DIR", tmp_path)
    
    content = b"data"
    safe_name, path = await save_upload("../../../etc/passwd", content)
    
    assert ".." not in safe_name
    assert "/" not in safe_name
    assert path.exists()
