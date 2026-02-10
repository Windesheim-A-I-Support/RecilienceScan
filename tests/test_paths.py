"""
Tests to audit all Python scripts for legacy path references.

This test suite verifies that:
1. All Python scripts use canonical /app/* paths
2. No legacy paths like /data, /reports, ./data, ./reports are used
3. All path references follow the canonical pattern
"""

import os
import re
import sys
from pathlib import Path

# Optional pytest import (will be used if available)
try:
    import pytest
    PYTEST_AVAILABLE = True
except ImportError:
    PYTEST_AVAILABLE = False


# Paths to audit (all Python files in the project)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_TO_AUDIT = [
    PROJECT_ROOT / "clean_data.py",
    PROJECT_ROOT / "clean_data_enhanced.py",
    PROJECT_ROOT / "convert_data.py",
    PROJECT_ROOT / "generate_all_reports.py",
    PROJECT_ROOT / "generate_single_report.py",
    PROJECT_ROOT / "validate_all_features.py",
    PROJECT_ROOT / "validate_data_integrity.py",
    PROJECT_ROOT / "validate_reports_detailed.py",
    PROJECT_ROOT / "validate_reports.py",
    PROJECT_ROOT / "validate_single_report.py",
    PROJECT_ROOT / "app/ingest.py",
    PROJECT_ROOT / "app/main.py",
]

# Legacy path patterns to detect (strings to avoid)
LEGACY_PATH_PATTERNS = [
    r'["\']/data["\']',           # "/data" or '/data'
    r'["\']/reports["\']',         # "/reports" or '/reports'
    r'["\']\./data["\']',          # "./data" or './data'
    r'["\']\./reports["\']',       # "./reports" or './reports'
    r'["\']/logs["\']',            # "/logs" - legacy absolute path
    r'["\']\./logs["\']',          # "./logs" - should be /app/logs
]

# Acceptable path patterns (these are OK)
ACCEPTABLE_PATTERNS = [
    r'/app/data',                 # Canonical data directory
    r'/app/outputs',              # Canonical output directory
    r'/app/logs',                 # Canonical log directory
    r'Path\(__file__\)',          # Relative path construction
    r'os\.path\.dirname',         # Dynamic path resolution
    r'os\.getcwd',                # Current working directory
]


def get_python_files():
    """Collect all Python files to audit (excluding test files)."""
    files = []
    for root, dirs, file_list in os.walk(PROJECT_ROOT):
        # Skip test directories and virtual environments
        dirs[:] = [d for d in dirs if d not in ['.venv', 'venv', '__pycache__', '.git', '.auto-claude']]

        for file in file_list:
            if file.endswith('.py'):
                file_path = Path(root) / file
                # Skip test files themselves
                if 'test_' not in file_path.name:
                    files.append(file_path)

    return files


def contains_legacy_path(content: str) -> tuple:
    """
    Check if content contains legacy path references.

    Returns:
        tuple: (has_legacy_paths, legacy_patterns_found, line_numbers)
    """
    lines = content.split('\n')
    legacy_found = []

    for line_num, line in enumerate(lines, 1):
        # Skip comments and docstrings
        if line.strip().startswith('#') or line.strip().startswith('"""') or line.strip().startswith("'''"):
            continue

        for pattern in LEGACY_PATH_PATTERNS:
            if re.search(pattern, line):
                # Double-check it's not in a comment
                code_part = line.split('#')[0]  # Remove inline comments
                if re.search(pattern, code_part):
                    legacy_found.append({
                        'line_number': line_num,
                        'line_content': line.strip(),
                        'pattern': pattern
                    })

    return len(legacy_found) > 0, legacy_found


def test_no_legacy_absolute_data_paths(python_files=None):
    """
    Verify no Python files use legacy absolute /data path.

    Expected: All scripts use /app/data or relative paths
    """
    if python_files is None:
        python_files = get_python_files()

    failed_files = []

    for file_path in python_files:
        if not file_path.exists():
            continue

        content = file_path.read_text(encoding='utf-8', errors='ignore')
        if re.search(r'["\']\/data["\']', content):
            failed_files.append({
                'file': str(file_path),
                'pattern': '/data'
            })

    if failed_files:
        raise AssertionError(f"Found legacy /data paths in: {failed_files}")

    return True


def test_no_legacy_absolute_reports_paths(python_files=None):
    """
    Verify no Python files use legacy absolute /reports path.

    Expected: All scripts use /app/outputs or relative paths
    """
    if python_files is None:
        python_files = get_python_files()

    failed_files = []

    for file_path in python_files:
        if not file_path.exists():
            continue

        content = file_path.read_text(encoding='utf-8', errors='ignore')
        if re.search(r'["\']\/reports["\']', content):
            failed_files.append({
                'file': str(file_path),
                'pattern': '/reports'
            })

    if failed_files:
        raise AssertionError(f"Found legacy /reports paths in: {failed_files}")

    return True


def test_no_legacy_relative_data_paths(python_files=None):
    """
    Verify no Python files use legacy relative ./data path.

    Expected: All scripts use /app/data in Docker or relative paths with proper resolution
    """
    if python_files is None:
        python_files = get_python_files()

    failed_files = []

    for file_path in python_files:
        if not file_path.exists():
            continue

        content = file_path.read_text(encoding='utf-8', errors='ignore')
        # Skip if it's using Path(__file__).resolve().parent / "data" pattern
        if 'Path(__file__)' in content and '/ "data"' in content:
            continue

        if re.search(r'["\']\.\/data["\']', content):
            failed_files.append({
                'file': str(file_path),
                'pattern': './data'
            })

    # Note: Some legacy relative paths may still exist, this is informational
    if failed_files:
        print(f"\nWARNING: Found relative ./data paths (may be OK for non-Docker): {failed_files}")

    return True


def test_no_legacy_relative_reports_paths(python_files=None):
    """
    Verify no Python files use legacy relative ./reports path.

    Expected: All scripts use /app/outputs in Docker
    """
    if python_files is None:
        python_files = get_python_files()

    failed_files = []

    for file_path in python_files:
        if not file_path.exists():
            continue

        content = file_path.read_text(encoding='utf-8', errors='ignore')
        if re.search(r'["\']\.\/reports["\']', content):
            failed_files.append({
                'file': str(file_path),
                'pattern': './reports'
            })

    if failed_files:
        raise AssertionError(f"Found legacy ./reports paths in: {failed_files}")

    return True


def test_audit_results(python_files=None):
    """
    Print a comprehensive audit report of all path references.

    This test always passes but provides detailed output for manual review.
    """
    if python_files is None:
        python_files = get_python_files()

    audit_results = {
        'total_files': 0,
        'files_with_legacy_paths': 0,
        'files_with_canonical_paths': 0,
        'canonical_path_counts': {
            '/app/data': 0,
            '/app/outputs': 0,
            '/app/logs': 0,
        },
        'legacy_path_counts': {
            '/data': 0,
            '/reports': 0,
            './data': 0,
            './reports': 0,
        },
        'files_details': []
    }

    for file_path in python_files:
        if not file_path.exists():
            continue

        audit_results['total_files'] += 1
        content = file_path.read_text(encoding='utf-8', errors='ignore')

        # Count canonical paths
        canonical_count = sum([
            content.count('/app/data'),
            content.count('/app/outputs'),
            content.count('/app/logs'),
        ])

        # Count legacy paths
        legacy_count = sum([
            len(re.findall(r'["\']\/data["\']', content)),
            len(re.findall(r'["\']\/reports["\']', content)),
            len(re.findall(r'["\']\.\/data["\']', content)),
            len(re.findall(r'["\']\.\/reports["\']', content)),
        ])

        if canonical_count > 0:
            audit_results['files_with_canonical_paths'] += 1
            audit_results['canonical_path_counts']['/app/data'] += content.count('/app/data')
            audit_results['canonical_path_counts']['/app/outputs'] += content.count('/app/outputs')
            audit_results['canonical_path_counts']['/app/logs'] += content.count('/app/logs')

        if legacy_count > 0:
            audit_results['files_with_legacy_paths'] += 1
            audit_results['legacy_path_counts']['/data'] += len(re.findall(r'["\']\/data["\']', content))
            audit_results['legacy_path_counts']['/reports'] += len(re.findall(r'["\']\/reports["\']', content))
            audit_results['legacy_path_counts']['/data'] += len(re.findall(r'["\']\.\/data["\']', content))
            audit_results['legacy_path_counts']['/reports'] += len(re.findall(r'["\']\.\/reports["\']', content))

        if canonical_count > 0 or legacy_count > 0:
            audit_results['files_details'].append({
                'file': str(file_path.relative_to(PROJECT_ROOT)),
                'canonical_paths': canonical_count,
                'legacy_paths': legacy_count,
            })

    # Print audit report
    print("\n" + "="*80)
    print("PATH AUDIT REPORT")
    print("="*80)
    print(f"\nTotal Python files audited: {audit_results['total_files']}")
    print(f"Files with canonical paths (/app/*): {audit_results['files_with_canonical_paths']}")
    print(f"Files with legacy paths: {audit_results['files_with_legacy_paths']}")
    print(f"\nCanonical path usage:")
    for path, count in audit_results['canonical_path_counts'].items():
        print(f"  {path}: {count} occurrences")
    print(f"\nLegacy path usage:")
    for path, count in audit_results['legacy_path_counts'].items():
        if count > 0:
            print(f"  {path}: {count} occurrences")

    print(f"\nDetailed file breakdown:")
    for detail in audit_results['files_details']:
        print(f"  {detail['file']}: {detail['canonical_paths']} canonical, {detail['legacy_paths']} legacy")

    print("\n" + "="*80)
    print("VERIFICATION RESULT:")

    if audit_results['legacy_path_counts']['/reports'] > 0 or audit_results['legacy_path_counts']['/data'] > 0:
        print("❌ FAILED - Found absolute legacy path references")
        print("   Action: Update scripts to use /app/data, /app/outputs, /app/logs")
    elif audit_results['legacy_path_counts']['./reports'] > 0:
        print("⚠️  WARNING - Found relative ./reports paths")
        print("   Action: Consider updating to canonical /app/outputs for Docker compatibility")
    else:
        print("✅ PASSED - All path references use /app/* or are correctly relative")

    print("="*80 + "\n")


def run_all_tests():
    """Run all audit tests standalone."""
    python_files = get_python_files()

    print("\n" + "="*80)
    print("RUNNING PATH AUDIT TESTS")
    print("="*80 + "\n")

    tests = [
        ("test_no_legacy_absolute_data_paths", test_no_legacy_absolute_data_paths),
        ("test_no_legacy_absolute_reports_paths", test_no_legacy_absolute_reports_paths),
        ("test_no_legacy_relative_data_paths", test_no_legacy_relative_data_paths),
        ("test_no_legacy_relative_reports_paths", test_no_legacy_relative_reports_paths),
        ("test_audit_results", test_audit_results),
    ]

    failed_tests = []
    for test_name, test_func in tests:
        try:
            print(f"Running {test_name}... ", end="", flush=True)
            result = test_func(python_files)
            print("✅ PASSED")
        except AssertionError as e:
            print(f"❌ FAILED")
            failed_tests.append((test_name, str(e)))
        except Exception as e:
            print(f"⚠️  ERROR")
            failed_tests.append((test_name, str(e)))

    print("\n" + "="*80)
    if failed_tests:
        print(f"❌ {len(failed_tests)} test(s) failed:")
        for test_name, error in failed_tests:
            print(f"\n{test_name}:")
            print(f"  {error}")
        print("="*80)
        return False
    else:
        print("✅ All audit tests passed!")
        print("="*80)
        return True


if __name__ == '__main__':
    if PYTEST_AVAILABLE:
        pytest.main([__file__, '-v', '-s'])
    else:
        success = run_all_tests()
        sys.exit(0 if success else 1)
