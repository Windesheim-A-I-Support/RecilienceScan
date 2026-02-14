import subprocess
import sys
import shutil
from pathlib import Path

BASE_DIR = Path("/app")
DATA_DIR = BASE_DIR / "data"
OUTPUTS_DIR = BASE_DIR / "outputs"


def run_step(description, command):
    print(f"\n=== {description} ===")
    result = subprocess.run(command)
    if result.returncode != 0:
        print(f"[ERROR] Step failed: {description}")
        sys.exit(result.returncode)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pipeline_runner.py <input_excel_path>")
        sys.exit(1)

    input_file = Path(sys.argv[1])

    if not input_file.exists():
        print(f"[ERROR] Input file not found: {input_file}")
        sys.exit(1)

    # ------------------------------------------------------------------
    # Step 1: Convert Excel → cleaned_master.csv
    # ------------------------------------------------------------------
    run_step(
        "Step 1: Converting data",
        ["python3", "convert_data.py", str(input_file)]
    )

    cleaned_csv_outputs = OUTPUTS_DIR / "cleaned_master.csv"
    cleaned_csv_data = DATA_DIR / "cleaned_master.csv"

    if cleaned_csv_outputs.exists():
        print("[INFO] Moving cleaned_master.csv to /app/data")
        shutil.move(str(cleaned_csv_outputs), str(cleaned_csv_data))

    if not cleaned_csv_data.exists():
        print("[ERROR] cleaned_master.csv not found after conversion")
        sys.exit(1)

    # ------------------------------------------------------------------
    # Step 2: Enhanced Cleaning
    # ------------------------------------------------------------------
    run_step(
        "Step 2: Enhanced data cleaning",
        ["python3", "clean_data_enhanced.py"]
    )

    # ------------------------------------------------------------------
    # IMPORTANT FIX:
    # Some legacy scripts expect cleaned_master in /outputs
    # Copy it there AFTER cleaning
    # ------------------------------------------------------------------
    print("[INFO] Syncing cleaned_master.csv to /app/outputs")
    shutil.copy(str(cleaned_csv_data), str(OUTPUTS_DIR / "cleaned_master.csv"))

    # ------------------------------------------------------------------
    # Step 3: Validate Cleaned Data
    # ------------------------------------------------------------------
    run_step(
        "Step 3: Validating cleaned data",
        ["python3", "validate_data_integrity.py"]
    )

    # ------------------------------------------------------------------
    # Step 4: Generate Reports
    # ------------------------------------------------------------------
    run_step(
        "Step 4: Generating reports",
        ["python3", "generate_all_reports.py"]
    )

    # ------------------------------------------------------------------
    # Step 5: Validate Reports
    # ------------------------------------------------------------------
    run_step(
        "Step 5: Validating reports",
        ["python3", "validate_reports_detailed.py"]
    )

    print("\n=== Pipeline completed successfully ===")


if __name__ == "__main__":
    main()
