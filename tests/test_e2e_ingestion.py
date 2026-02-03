"""
End-to-end verification tests for the P2 data ingestion pipeline.
Validates the full ingest_file() flow against real XLSX data.
"""
import os
import re
import sys
import shutil

import pandas as pd

# Ensure project root is on path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.ingest import ingest_file, ingest_directory

# Paths
DATA_DIR = "./data"
XLSX_PATH = "./data/Resilience - MasterDatabase (1).xlsx"
MASTER_DB_PATH = "./data/master_database.csv"
CLEANED_PATH = "./data/cleaned_master.csv"
LOG_PATH = "./logs/ingestion.log"
BACKUP_DIR = "./data/backups"


def clean_slate():
    """Remove all generated outputs for a fresh test run."""
    # Close any existing logging handlers to release file locks
    import logging
    ingestion_logger = logging.getLogger("ingestion")
    for handler in ingestion_logger.handlers[:]:
        handler.close()
        ingestion_logger.removeHandler(handler)

    for f in [MASTER_DB_PATH, CLEANED_PATH, LOG_PATH]:
        if os.path.exists(f):
            os.remove(f)
    if os.path.exists(BACKUP_DIR):
        shutil.rmtree(BACKUP_DIR)

    # Force reimport to reinitialize logger with fresh handler
    import importlib
    import app.ingest
    importlib.reload(app.ingest)


def test_fresh_ingestion():
    """Step 1: Ingest real XLSX on clean slate."""
    clean_slate()
    from app.ingest import ingest_file as _ingest_file
    result = _ingest_file(XLSX_PATH)
    assert result["status"] == "success", f"Ingestion failed: {result.get('error')}"
    assert result["rows_loaded"] == 565, f"Expected 565 rows, got {result['rows_loaded']}"
    assert result["format"] == "xlsx"
    assert result["encoding"] == "binary"
    print("[PASS] test_fresh_ingestion")
    return result


def test_csv_outputs():
    """Step 2-3: Verify both CSVs exist with correct shape."""
    assert os.path.exists(MASTER_DB_PATH), "master_database.csv missing"
    assert os.path.exists(CLEANED_PATH), "cleaned_master.csv missing"

    master = pd.read_csv(MASTER_DB_PATH, encoding="utf-8")
    cleaned = pd.read_csv(CLEANED_PATH, encoding="utf-8")

    assert master.shape[0] == 565, f"master rows: {master.shape[0]}"
    assert cleaned.shape[0] == 565, f"cleaned rows: {cleaned.shape[0]}"
    assert set(master.columns).issuperset(set(cleaned.columns)), "master not superset"

    # Verify UTF-8 encoding
    with open(CLEANED_PATH, encoding="utf-8") as f:
        f.read()
    with open(MASTER_DB_PATH, encoding="utf-8") as f:
        f.read()

    print("[PASS] test_csv_outputs")


def test_audit_log():
    """Step 4: Verify structured audit log."""
    assert os.path.exists(LOG_PATH), "ingestion.log missing"
    with open(LOG_PATH, encoding="utf-8") as f:
        content = f.read()

    assert "INGESTION" in content, "No INGESTION entry"
    assert "source=" in content, "No source field"
    assert "format=" in content, "No format field"
    assert "encoding=" in content, "No encoding field"
    assert "rows_loaded=" in content, "No rows_loaded field"
    assert "rows_added=" in content, "No rows_added field"
    assert re.search(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", content), "No timestamp"
    print("[PASS] test_audit_log")


def test_backup_on_reingest():
    """Step 5: Re-ingest creates backup of existing cleaned_master.csv."""
    result = ingest_file(XLSX_PATH)
    assert result["status"] == "success", f"Re-ingestion failed: {result.get('error')}"
    assert os.path.exists(BACKUP_DIR), "backups dir not created"
    backups = os.listdir(BACKUP_DIR)
    assert len(backups) > 0, "No backup files found"

    # Verify row count preserved
    cleaned = pd.read_csv(CLEANED_PATH, encoding="utf-8")
    assert cleaned.shape[0] == 565, f"Rows changed after re-ingest: {cleaned.shape[0]}"
    print("[PASS] test_backup_on_reingest")


def test_column_normalization():
    """Step 6: Verify all columns are normalized."""
    df = pd.read_csv(CLEANED_PATH, encoding="utf-8")
    for col in df.columns:
        assert col == col.lower(), f"Not lowercase: {col}"
        assert " " not in col, f"Has spaces: {col}"
        assert re.match(r"^[a-z_][a-z0-9_]*$", col), f"Invalid chars: {col}"
    print(f"[PASS] test_column_normalization ({len(df.columns)} columns)")


def test_module_imports():
    """Step 7: Verify module is importable."""
    from app.ingest import ingest_file, ingest_directory
    assert callable(ingest_file)
    assert callable(ingest_directory)
    print("[PASS] test_module_imports")


def test_existing_scripts_parseable():
    """Steps 8-9: Verify convert_data.py and clean_data.py still parse."""
    import ast
    for script in ["convert_data.py", "clean_data.py"]:
        with open(script, "r", encoding="utf-8") as f:
            ast.parse(f.read())
    print("[PASS] test_existing_scripts_parseable")


if __name__ == "__main__":
    print("=" * 70)
    print("END-TO-END INGESTION VERIFICATION")
    print("=" * 70)

    tests = [
        test_fresh_ingestion,
        test_csv_outputs,
        test_audit_log,
        test_backup_on_reingest,
        test_column_normalization,
        test_module_imports,
        test_existing_scripts_parseable,
    ]

    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"[FAIL] {test.__name__}: {e}")
            failed += 1

    print()
    print("=" * 70)
    print(f"Results: {passed} passed, {failed} failed out of {len(tests)} tests")
    print("=" * 70)
    sys.exit(1 if failed > 0 else 0)
