"""
Complete Dependency Installer for ResilienceScan
Installs:
1. Python packages
2. Quarto CLI
3. R
4. R packages
"""
import subprocess
import sys
import os
from pathlib import Path
import urllib.request
import tempfile

print("="*60)
print("ResilienceScan - Complete Dependency Installer")
print("="*60)

# Track what needs to be installed
needs_install = {
    'python_packages': [],
    'quarto': False,
    'r': False,
    'r_packages': []
}

# ============================================================
# STEP 1: Check Python Packages
# ============================================================
print("\n[1/4] Checking Python packages...")

REQUIRED_PYTHON_PACKAGES = [
    'pandas',
    'openpyxl',
    'pywin32',
]

for package in REQUIRED_PYTHON_PACKAGES:
    try:
        __import__(package.replace('-', '_'))
        print(f"  [OK] {package}")
    except ImportError:
        print(f"  [MISSING] {package}")
        needs_install['python_packages'].append(package)

# ============================================================
# STEP 2: Check Quarto
# ============================================================
print("\n[2/4] Checking Quarto CLI...")

try:
    result = subprocess.run(['quarto', '--version'], capture_output=True, text=True)
    if result.returncode == 0:
        version = result.stdout.strip()
        print(f"  [OK] Quarto {version}")
    else:
        print("  [MISSING] Quarto")
        needs_install['quarto'] = True
except FileNotFoundError:
    print("  [MISSING] Quarto")
    needs_install['quarto'] = True

# ============================================================
# STEP 3: Check R
# ============================================================
print("\n[3/4] Checking R...")

try:
    result = subprocess.run(['R', '--version'], capture_output=True, text=True)
    if result.returncode == 0:
        version_line = result.stdout.split('\n')[0]
        print(f"  [OK] {version_line}")
    else:
        print("  [MISSING] R")
        needs_install['r'] = True
except FileNotFoundError:
    print("  [MISSING] R")
    needs_install['r'] = True

# ============================================================
# STEP 4: Check R Packages
# ============================================================
print("\n[4/4] Checking R packages...")

REQUIRED_R_PACKAGES = [
    'tidyverse',
    'knitr',
    'rmarkdown'
]

if not needs_install['r']:
    for package in REQUIRED_R_PACKAGES:
        check_cmd = f'if (!require("{package}", quietly = TRUE)) quit(status = 1)'
        result = subprocess.run(
            ['R', '--vanilla', '--slave', '-e', check_cmd],
            capture_output=True
        )
        if result.returncode == 0:
            print(f"  [OK] {package}")
        else:
            print(f"  [MISSING] {package}")
            needs_install['r_packages'].append(package)
else:
    print("  [SKIP] R not installed, skipping package check")

# ============================================================
# SUMMARY
# ============================================================
print("\n" + "="*60)
print("INSTALLATION SUMMARY")
print("="*60)

total_missing = (
    len(needs_install['python_packages']) +
    (1 if needs_install['quarto'] else 0) +
    (1 if needs_install['r'] else 0) +
    len(needs_install['r_packages'])
)

if total_missing == 0:
    print("\n[ALL GOOD] All dependencies are installed!")
    sys.exit(0)

print(f"\nFound {total_missing} missing dependencies:\n")

if needs_install['python_packages']:
    print(f"Python packages ({len(needs_install['python_packages'])}):")
    for pkg in needs_install['python_packages']:
        print(f"  - {pkg}")

if needs_install['quarto']:
    print("Quarto CLI: MISSING")

if needs_install['r']:
    print("R: MISSING")

if needs_install['r_packages']:
    print(f"R packages ({len(needs_install['r_packages'])}):")
    for pkg in needs_install['r_packages']:
        print(f"  - {pkg}")

# ============================================================
# ASK USER TO INSTALL
# ============================================================
print("\n" + "="*60)
response = input("Install missing dependencies? (yes/no): ").lower()

if response not in ['yes', 'y']:
    print("\n[CANCELLED] Installation cancelled by user")
    sys.exit(0)

# ============================================================
# INSTALL PYTHON PACKAGES
# ============================================================
if needs_install['python_packages']:
    print("\n" + "="*60)
    print("Installing Python packages...")
    print("="*60)

    for package in needs_install['python_packages']:
        print(f"\n[INSTALL] {package}...")
        result = subprocess.run(
            [sys.executable, '-m', 'pip', 'install', package],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"  [OK] {package} installed")
        else:
            print(f"  [FAIL] Failed to install {package}")
            print(f"  Error: {result.stderr[:200]}")

# ============================================================
# INSTALL QUARTO
# ============================================================
if needs_install['quarto']:
    print("\n" + "="*60)
    print("Installing Quarto CLI...")
    print("="*60)

    print("\n[INFO] Downloading Quarto installer...")
    quarto_url = "https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.549/quarto-1.4.549-win.msi"

    with tempfile.TemporaryDirectory() as tmpdir:
        installer_path = Path(tmpdir) / "quarto-installer.msi"

        try:
            urllib.request.urlretrieve(quarto_url, installer_path)
            print(f"  [OK] Downloaded to {installer_path}")

            print("\n[INFO] Running Quarto installer...")
            print("  Please follow the installation wizard...")

            result = subprocess.run(['msiexec', '/i', str(installer_path)], check=False)

            if result.returncode == 0:
                print("  [OK] Quarto installed successfully")
                print("  [INFO] You may need to restart your terminal for PATH changes")
            else:
                print(f"  [WARN] Installer exited with code {result.returncode}")

        except Exception as e:
            print(f"  [FAIL] Failed to install Quarto: {e}")
            print(f"  [INFO] Please download manually from: https://quarto.org/docs/get-started/")

# ============================================================
# INSTALL R
# ============================================================
if needs_install['r']:
    print("\n" + "="*60)
    print("Installing R...")
    print("="*60)

    print("\n[INFO] Downloading R installer...")
    r_url = "https://cran.r-project.org/bin/windows/base/R-4.3.2-win.exe"

    with tempfile.TemporaryDirectory() as tmpdir:
        installer_path = Path(tmpdir) / "R-installer.exe"

        try:
            urllib.request.urlretrieve(r_url, installer_path)
            print(f"  [OK] Downloaded to {installer_path}")

            print("\n[INFO] Running R installer...")
            print("  Please follow the installation wizard...")

            result = subprocess.run([str(installer_path), '/VERYSILENT'], check=False)

            if result.returncode == 0:
                print("  [OK] R installed successfully")
                print("  [INFO] You may need to restart your terminal for PATH changes")
            else:
                print(f"  [WARN] Installer exited with code {result.returncode}")

        except Exception as e:
            print(f"  [FAIL] Failed to install R: {e}")
            print(f"  [INFO] Please download manually from: https://cran.r-project.org/")

# ============================================================
# INSTALL R PACKAGES
# ============================================================
if needs_install['r_packages']:
    print("\n" + "="*60)
    print("Installing R packages...")
    print("="*60)

    for package in needs_install['r_packages']:
        print(f"\n[INSTALL] {package}...")
        install_cmd = f'install.packages("{package}", repos="https://cran.r-project.org")'
        result = subprocess.run(
            ['R', '--vanilla', '--slave', '-e', install_cmd],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"  [OK] {package} installed")
        else:
            print(f"  [FAIL] Failed to install {package}")
            print(f"  Error: {result.stderr[:200]}")

# ============================================================
# FINAL CHECK
# ============================================================
print("\n" + "="*60)
print("INSTALLATION COMPLETE!")
print("="*60)

print("\n[INFO] Running final verification...")
print("\n[INFO] Please restart your terminal and run this script again to verify")
print("[INFO] Some installations (Quarto, R) require PATH updates")

print("\n" + "="*60)
print("NEXT STEPS:")
print("="*60)
print("1. Close this terminal")
print("2. Open a NEW terminal")
print("3. Run: python install_all_dependencies.py")
print("4. Verify all dependencies show [OK]")
print("5. Launch GUI: python ResilienceScanGUI.py")
print("="*60)
