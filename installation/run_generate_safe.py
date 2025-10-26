"""
Wrapper to run generate_all_reports.py with Windows encoding fix
"""
import sys
import io
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(
        sys.stdout.buffer,
        encoding='utf-8',
        errors='replace'
    )
    sys.stderr = io.TextIOWrapper(
        sys.stderr.buffer,
        encoding='utf-8',
        errors='replace'
    )

# Add parent directory to path so we can import from root
script_dir = Path(__file__).resolve().parent
root_dir = script_dir.parent
sys.path.insert(0, str(root_dir))

# Now import and run generate_all_reports
import generate_all_reports

if __name__ == "__main__":
    try:
        generate_all_reports.generate_reports()
    except KeyboardInterrupt:
        print("\n[CANCELLED] Report generation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
