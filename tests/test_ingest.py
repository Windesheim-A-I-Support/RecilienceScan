"""
Unit tests for app.ingest module.

12 required tests per spec QA Acceptance Criteria:
  1. test_load_xlsx
  2. test_load_csv
  3. test_load_tsv
  4. test_encoding_cascade
  5. test_normalize_columns
  6. test_upsert_no_overwrite
  7. test_upsert_fill_empty
  8. test_upsert_new_rows
  9. test_schema_evolution
  10. test_empty_file
  11. test_locked_file
  12. test_missing_primary_key

All tests use tmp_path fixture for file isolation and are independent.
"""

import os
import sys
import pytest
import pandas as pd
import numpy as np

# Ensure project root is on path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.ingest import (
    load_xlsx,
    load_csv_tsv,
    read_with_encoding_cascade,
    normalize_columns,
    safe_upsert_merge,
    evolve_schema,
    ingest_file,
)


# ---------------------------------------------------------------------------
# Helpers to create test files
# ---------------------------------------------------------------------------

def _create_xlsx(path, data, header=True):
    """Create a minimal XLSX file from a dict of columns."""
    df = pd.DataFrame(data)
    df.to_excel(str(path), index=False, header=header, engine="openpyxl")
    return path


def _create_csv(path, data, encoding="utf-8", delimiter=","):
    """Create a CSV file from a dict of columns."""
    df = pd.DataFrame(data)
    df.to_csv(str(path), index=False, encoding=encoding, sep=delimiter)
    return path


# ---------------------------------------------------------------------------
# 1. test_load_xlsx — XLSX file loads correctly, headers detected, DataFrame returned
# ---------------------------------------------------------------------------

def test_load_xlsx(tmp_path):
    """XLSX file loads correctly, headers detected, DataFrame returned."""
    xlsx_file = tmp_path / "test_data.xlsx"
    data = {
        "Company Name": ["Acme Corp", "Beta Inc", "Gamma Ltd"],
        "Email Address": ["a@a.com", "b@b.com", "c@c.com"],
        "Score": [10, 20, 30],
    }
    _create_xlsx(xlsx_file, data)

    df = load_xlsx(str(xlsx_file))

    assert df is not None, "load_xlsx returned None"
    assert len(df) == 3, f"Expected 3 rows, got {len(df)}"
    assert len(df.columns) == 3, f"Expected 3 columns, got {len(df.columns)}"
    # Headers should be detected
    col_strs = [str(c).lower() for c in df.columns]
    assert any("company" in c for c in col_strs), f"Header 'Company' not detected in {df.columns.tolist()}"


# ---------------------------------------------------------------------------
# 2. test_load_csv — CSV file loads with correct delimiter and encoding
# ---------------------------------------------------------------------------

def test_load_csv(tmp_path):
    """CSV file loads with correct delimiter and encoding."""
    csv_file = tmp_path / "test_data.csv"
    data = {
        "Company Name": ["Acme Corp", "Beta Inc", "Gamma Ltd"],
        "Email Address": ["a@a.com", "b@b.com", "c@c.com"],
        "UP - Score": [10, 20, 30],
    }
    _create_csv(csv_file, data, encoding="utf-8", delimiter=",")

    df = load_csv_tsv(str(csv_file))

    assert df is not None, "load_csv_tsv returned None for CSV"
    assert len(df) == 3, f"Expected 3 rows, got {len(df)}"
    assert len(df.columns) == 3, f"Expected 3 columns, got {len(df.columns)}"


# ---------------------------------------------------------------------------
# 3. test_load_tsv — TSV file loads with tab delimiter auto-detected
# ---------------------------------------------------------------------------

def test_load_tsv(tmp_path):
    """TSV file loads with tab delimiter auto-detected."""
    tsv_file = tmp_path / "test_data.tsv"
    data = {
        "Company Name": ["Acme Corp", "Beta Inc", "Gamma Ltd"],
        "Email Address": ["a@a.com", "b@b.com", "c@c.com"],
        "Score": [10, 20, 30],
    }
    _create_csv(tsv_file, data, encoding="utf-8", delimiter="\t")

    df = load_csv_tsv(str(tsv_file))

    assert df is not None, "load_csv_tsv returned None for TSV"
    assert len(df) == 3, f"Expected 3 rows, got {len(df)}"
    assert len(df.columns) == 3, f"Expected 3 columns, got {len(df.columns)}"


# ---------------------------------------------------------------------------
# 4. test_encoding_cascade — Files with cp1252/latin1 encoding load via fallback
# ---------------------------------------------------------------------------

def test_encoding_cascade(tmp_path):
    """Files with cp1252/latin1 encoding load via fallback chain."""
    # Create a file with cp1252 encoding containing special characters
    cp1252_file = tmp_path / "cp1252_data.csv"
    content = "Company Name,Email Address,Score\nAcmé Corp,a@a.com,10\nBêta Inc,b@b.com,20\nGàmma Ltd,c@c.com,30\n"
    with open(str(cp1252_file), "w", encoding="cp1252") as f:
        f.write(content)

    # read_with_encoding_cascade should succeed via fallback
    text, encoding_used = read_with_encoding_cascade(str(cp1252_file))

    assert text is not None, "Encoding cascade returned None"
    assert len(text) > 0, "Encoding cascade returned empty string"
    assert encoding_used in ("utf-8", "utf-8-sig", "cp1252", "latin1"), (
        f"Unexpected encoding: {encoding_used}"
    )
    # Content should be readable
    assert "Acm" in text, "Content not readable after encoding cascade"


# ---------------------------------------------------------------------------
# 5. test_normalize_columns — Column names normalized correctly
# ---------------------------------------------------------------------------

def test_normalize_columns():
    """Column names normalized: lowercase, underscores, no special chars."""
    df = pd.DataFrame(
        {
            "Company Name": [1],
            " Email Address ": [2],
            "UP - R": [3],
            "3rd Party": [4],
            "Score (%)": [5],
        }
    )

    result = normalize_columns(df)

    cols = list(result.columns)
    # All columns should be lowercase
    assert all(c == c.lower() for c in cols), f"Not all lowercase: {cols}"
    # No spaces
    assert all(" " not in c for c in cols), f"Spaces found in: {cols}"
    # company_name should be present
    assert "company_name" in cols, f"company_name not found in {cols}"
    # Digit-prefixed column should have col_ prefix
    digit_cols = [c for c in cols if "3rd" in c or "party" in c]
    assert any(c.startswith("col_") for c in digit_cols), (
        f"Digit-prefix column not prefixed with col_: {digit_cols}"
    )


# ---------------------------------------------------------------------------
# 6. test_upsert_no_overwrite — Existing non-empty values preserved during merge
# ---------------------------------------------------------------------------

def test_upsert_no_overwrite():
    """Existing non-empty values preserved during merge."""
    existing = pd.DataFrame(
        {"company_name": ["A", "B"], "score": [10, 20], "note": ["hello", "world"]}
    )
    incoming = pd.DataFrame(
        {"company_name": ["A", "B"], "score": [99, 88], "note": ["new_a", "new_b"]}
    )

    result, stats = safe_upsert_merge(existing, incoming, "company_name")

    # Existing non-empty values must NOT be overwritten
    a_score = result.loc[result["company_name"] == "A", "score"].iloc[0]
    assert a_score == 10, f"Non-empty score overwritten: expected 10, got {a_score}"
    b_score = result.loc[result["company_name"] == "B", "score"].iloc[0]
    assert b_score == 20, f"Non-empty score overwritten: expected 20, got {b_score}"
    a_note = result.loc[result["company_name"] == "A", "note"].iloc[0]
    assert a_note == "hello", f"Non-empty note overwritten: expected 'hello', got {a_note}"


# ---------------------------------------------------------------------------
# 7. test_upsert_fill_empty — Empty fields filled with new non-empty values
# ---------------------------------------------------------------------------

def test_upsert_fill_empty():
    """Empty fields filled with new non-empty values."""
    existing = pd.DataFrame(
        {"company_name": ["A"], "score": [pd.NA], "note": ["hello"]}
    )
    incoming = pd.DataFrame(
        {"company_name": ["A"], "score": [50], "note": ["bye"]}
    )

    result, stats = safe_upsert_merge(existing, incoming, "company_name")

    # Empty score should be filled with incoming value
    a_score = result.loc[result["company_name"] == "A", "score"].iloc[0]
    assert str(a_score) == "50", f"Empty field not filled: expected 50, got {a_score}"
    # Non-empty note should be preserved
    a_note = result.loc[result["company_name"] == "A", "note"].iloc[0]
    assert a_note == "hello", f"Non-empty note overwritten: expected 'hello', got {a_note}"
    # Stats should reflect the update
    assert stats["rows_updated"] == 1, f"Expected 1 updated, got {stats['rows_updated']}"


# ---------------------------------------------------------------------------
# 8. test_upsert_new_rows — New rows appended to master
# ---------------------------------------------------------------------------

def test_upsert_new_rows():
    """New rows appended to master."""
    existing = pd.DataFrame(
        {"company_name": ["A", "B"], "score": [10, 20]}
    )
    incoming = pd.DataFrame(
        {"company_name": ["C", "D"], "score": [30, 40]}
    )

    result, stats = safe_upsert_merge(existing, incoming, "company_name")

    assert len(result) == 4, f"Expected 4 rows (2 existing + 2 new), got {len(result)}"
    assert stats["rows_added"] == 2, f"Expected 2 added, got {stats['rows_added']}"
    # All original rows still present
    assert "A" in result["company_name"].values
    assert "B" in result["company_name"].values
    assert "C" in result["company_name"].values
    assert "D" in result["company_name"].values


# ---------------------------------------------------------------------------
# 9. test_schema_evolution — New columns added, existing rows backfilled with empty
# ---------------------------------------------------------------------------

def test_schema_evolution():
    """New columns added to master, existing rows backfilled with empty."""
    master = pd.DataFrame(
        {"company_name": ["A", "B"], "score": [10, 20]}
    )
    incoming = pd.DataFrame(
        {"company_name": ["C"], "score": [30], "new_col": ["val"], "extra": [99]}
    )

    result, added_cols = evolve_schema(master, incoming)

    assert "new_col" in result.columns, f"new_col not added: {result.columns.tolist()}"
    assert "extra" in result.columns, f"extra not added: {result.columns.tolist()}"
    assert sorted(added_cols) == ["extra", "new_col"], f"Unexpected added_cols: {added_cols}"
    # Existing rows should have NA for new columns
    assert pd.isna(result.loc[0, "new_col"]), "Existing row not backfilled with NA"
    assert pd.isna(result.loc[1, "new_col"]), "Existing row not backfilled with NA"


# ---------------------------------------------------------------------------
# 10. test_empty_file — Empty file handled gracefully without crash
# ---------------------------------------------------------------------------

def test_empty_file(tmp_path):
    """Empty file handled gracefully without crash."""
    empty_file = tmp_path / "empty.csv"
    empty_file.write_text("", encoding="utf-8")

    # load_csv_tsv should return None for empty file, not crash
    result = load_csv_tsv(str(empty_file))
    assert result is None, f"Expected None for empty file, got {type(result)}"

    # ingest_file should handle gracefully too
    stats = ingest_file(str(empty_file))
    assert stats is not None, "ingest_file returned None"
    assert stats["status"] != "success" or stats["rows_loaded"] == 0, (
        "Empty file should not report successful loading of rows"
    )


# ---------------------------------------------------------------------------
# 11. test_locked_file — PermissionError caught and logged, no crash
# ---------------------------------------------------------------------------

def test_locked_file(tmp_path):
    """PermissionError caught and logged, no crash."""
    locked_file = tmp_path / "locked.xlsx"
    locked_file.write_bytes(b"fake xlsx content")

    # Make file unreadable (simulate lock) - platform-specific approach
    if sys.platform == "win32":
        # On Windows, remove read permission
        import stat
        os.chmod(str(locked_file), 0o000)
        try:
            result = load_xlsx(str(locked_file))
            # Should return None (handled gracefully), not crash
            assert result is None, "Expected None for locked/unreadable file"
        finally:
            # Restore permissions for cleanup
            os.chmod(str(locked_file), stat.S_IRUSR | stat.S_IWUSR)
    else:
        # On Unix, remove all permissions
        os.chmod(str(locked_file), 0o000)
        try:
            result = load_xlsx(str(locked_file))
            assert result is None, "Expected None for locked/unreadable file"
        finally:
            os.chmod(str(locked_file), 0o644)


# ---------------------------------------------------------------------------
# 12. test_missing_primary_key — Falls back to append-only when company_name missing
# ---------------------------------------------------------------------------

def test_missing_primary_key():
    """Falls back to append-only when company_name missing."""
    # DataFrames without company_name column
    existing = pd.DataFrame({"name": ["A", "B"], "score": [10, 20]})
    incoming = pd.DataFrame({"name": ["C", "D"], "score": [30, 40]})

    result, stats = safe_upsert_merge(existing, incoming, "company_name")

    # Should fall back to append-only: all rows concatenated
    assert len(result) == 4, f"Expected 4 rows in append-only mode, got {len(result)}"
    assert stats["rows_added"] == 2, f"Expected 2 added in append-only, got {stats['rows_added']}"
