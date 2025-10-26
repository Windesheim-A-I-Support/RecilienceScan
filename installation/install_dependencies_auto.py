"""
Automatic Dependency Installer (no prompts)
Run with: python install_dependencies_auto.py
"""
import subprocess
import sys

print("="*60)
print("Auto-Installing ALL Dependencies")
print("="*60)

# Install Python packages
print("\n[1/3] Installing Python packages...")
packages = ['pandas', 'openpyxl', 'pywin32']

for pkg in packages:
    print(f"\n  Installing {pkg}...")
    result = subprocess.run(
        [sys.executable, '-m', 'pip', 'install', pkg],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print(f"    [OK] {pkg}")
    else:
        print(f"    [FAIL] {pkg}: {result.stderr[:100]}")

print("\n" + "="*60)
print("Python packages installed!")
print("="*60)

print("\nFor Quarto and R:")
print("1. Download Quarto: https://quarto.org/docs/get-started/")
print("2. Download R: https://cran.r-project.org/bin/windows/base/")
print("3. After installing, run: python install_all_dependencies.py")
print("="*60)
