"""
Wrapper to run clean_data.py with Windows encoding fix
"""
import sys
import io

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

# Now import and run clean_data
import clean_data

if __name__ == "__main__":
    success = clean_data.clean_and_save()
    sys.exit(0 if success else 1)
