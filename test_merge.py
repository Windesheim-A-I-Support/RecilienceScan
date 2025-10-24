#!/usr/bin/env python3
"""
Test script for CSV merge functionality
Creates test data and verifies merge behavior
"""

import pandas as pd
import os
import sys
from datetime import datetime

# Test data directory
TEST_DIR = "./data/test_merge"

def create_test_data():
    """Create test datasets for merge testing"""
    print("=" * 70)
    print("🧪 CREATING TEST DATA")
    print("=" * 70)

    os.makedirs(TEST_DIR, exist_ok=True)

    # Test 1: Existing data
    print("\n📝 Creating existing_data.csv...")
    df_existing = pd.DataFrame({
        'company_name': ['Company A', 'Company B', 'Company C'],
        'name': ['John Doe', 'Jane Smith', 'Bob Johnson'],
        'email_address': ['john@companya.com', 'jane@companyb.com', 'bob@companyc.com'],
        'score': [85, 90, 75],
        'submitdate': ['2025-01-01', '2025-01-02', '2025-01-03']
    })
    df_existing.to_csv(f"{TEST_DIR}/existing_data.csv", index=False)
    print(f"   ✅ Created with {len(df_existing)} rows")

    # Test 2: New data with new companies
    print("\n📝 Creating new_companies.csv...")
    df_new_companies = pd.DataFrame({
        'company_name': ['Company D', 'Company E'],
        'name': ['Alice Wilson', 'Charlie Brown'],
        'email_address': ['alice@companyd.com', 'charlie@companye.com'],
        'score': [88, 92],
        'submitdate': ['2025-01-15', '2025-01-16']
    })
    df_new_companies.to_csv(f"{TEST_DIR}/new_companies.csv", index=False)
    print(f"   ✅ Created with {len(df_new_companies)} rows")

    # Test 3: Updated data for existing companies
    print("\n📝 Creating updated_data.csv...")
    df_updated = pd.DataFrame({
        'company_name': ['Company A', 'Company B'],
        'name': ['John Doe', 'Jane Smith'],
        'email_address': ['john@companya.com', 'jane@companyb.com'],
        'score': [87, 93],  # Updated scores
        'submitdate': ['2025-01-20', '2025-01-21']  # New dates
    })
    df_updated.to_csv(f"{TEST_DIR}/updated_data.csv", index=False)
    print(f"   ✅ Created with {len(df_updated)} rows")

    # Test 4: Data with new column
    print("\n📝 Creating new_column_data.csv...")
    df_new_column = pd.DataFrame({
        'company_name': ['Company F'],
        'name': ['David Lee'],
        'email_address': ['david@companyf.com'],
        'score': [78],
        'submitdate': ['2025-01-25'],
        'new_field': ['extra_data']  # New column
    })
    df_new_column.to_csv(f"{TEST_DIR}/new_column_data.csv", index=False)
    print(f"   ✅ Created with {len(df_new_column)} rows and NEW COLUMN")

    print("\n✅ Test data created in:", TEST_DIR)
    return True


def test_merge_logic():
    """Test the merge logic from clean_data.py"""
    print("\n" + "=" * 70)
    print("🧪 TESTING MERGE LOGIC")
    print("=" * 70)

    # Import merge function from clean_data
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from clean_data import merge_dataframes

    # Load test data
    df_existing = pd.read_csv(f"{TEST_DIR}/existing_data.csv")
    df_new_companies = pd.read_csv(f"{TEST_DIR}/new_companies.csv")
    df_updated = pd.read_csv(f"{TEST_DIR}/updated_data.csv")
    df_new_column = pd.read_csv(f"{TEST_DIR}/new_column_data.csv")

    # Test 1: Merge with new companies (should append)
    print("\n" + "=" * 70)
    print("TEST 1: New Companies (should append)")
    print("=" * 70)
    df_result1 = merge_dataframes(df_existing.copy(), df_new_companies)
    print(f"\n📊 Result: {len(df_existing)} + {len(df_new_companies)} = {len(df_result1)} rows")
    expected = len(df_existing) + len(df_new_companies)
    if len(df_result1) == expected:
        print("✅ PASS: Correctly appended new companies")
    else:
        print(f"❌ FAIL: Expected {expected} rows, got {len(df_result1)}")

    # Test 2: Merge with updated data (should replace duplicates)
    print("\n" + "=" * 70)
    print("TEST 2: Updated Data (should replace duplicates)")
    print("=" * 70)
    df_result2 = merge_dataframes(df_existing.copy(), df_updated)
    print(f"\n📊 Result: {len(df_existing)} existing, {len(df_updated)} updates = {len(df_result2)} rows")
    # Should keep same number of rows (updates, not new)
    if len(df_result2) == len(df_existing):
        print("✅ PASS: Correctly updated existing records")
        # Check if scores were updated
        updated_score_a = df_result2[df_result2['company_name'] == 'Company A']['score'].values[0]
        if updated_score_a == 87:
            print("✅ PASS: Score correctly updated (85 → 87)")
        else:
            print(f"❌ FAIL: Score not updated (expected 87, got {updated_score_a})")
    else:
        print(f"❌ FAIL: Expected {len(df_existing)} rows, got {len(df_result2)}")

    # Test 3: Merge with new column (should add column)
    print("\n" + "=" * 70)
    print("TEST 3: New Column (should add column to all rows)")
    print("=" * 70)
    df_result3 = merge_dataframes(df_existing.copy(), df_new_column)
    print(f"\n📊 Result: {len(df_result3)} rows × {len(df_result3.columns)} columns")
    if 'new_field' in df_result3.columns:
        print("✅ PASS: New column added to dataframe")
        # Check if existing rows have NaN for new column
        na_count = df_result3['new_field'].isna().sum()
        print(f"   ℹ️  {na_count} rows have NaN for new_field (expected for existing data)")
    else:
        print("❌ FAIL: New column not added")

    # Test 4: Combined scenario
    print("\n" + "=" * 70)
    print("TEST 4: Combined Scenario (multiple merges)")
    print("=" * 70)
    df_result4 = df_existing.copy()
    df_result4 = merge_dataframes(df_result4, df_new_companies)
    df_result4 = merge_dataframes(df_result4, df_updated)
    df_result4 = merge_dataframes(df_result4, df_new_column)

    print(f"\n📊 Final result: {len(df_result4)} rows × {len(df_result4.columns)} columns")
    expected_rows = len(df_existing) + len(df_new_companies) + len(df_new_column)
    print(f"   Expected: {expected_rows} rows (3 original + 2 new companies + 1 new with extra column)")
    print(f"   Expected: 6 columns (5 original + 1 new)")

    if len(df_result4) == expected_rows and len(df_result4.columns) == 6:
        print("✅ PASS: Combined merge successful")
    else:
        print(f"⚠️  Rows: expected {expected_rows}, got {len(df_result4)}")
        print(f"⚠️  Cols: expected 6, got {len(df_result4.columns)}")

    print("\n" + "=" * 70)
    print("📋 FINAL MERGED DATA SAMPLE:")
    print("=" * 70)
    print(df_result4.to_string())

    return True


def cleanup_test_data():
    """Clean up test data"""
    import shutil
    if os.path.exists(TEST_DIR):
        shutil.rmtree(TEST_DIR)
        print(f"\n🗑️  Cleaned up test directory: {TEST_DIR}")


if __name__ == "__main__":
    try:
        create_test_data()
        test_merge_logic()

        # Auto cleanup test data
        print("\n" + "=" * 70)
        cleanup_test_data()

        print("\n✅ All tests completed!")

    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
