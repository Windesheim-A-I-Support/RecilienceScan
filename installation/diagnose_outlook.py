"""
Diagnostic script to identify Outlook COM issues
"""
import sys
import subprocess
from pathlib import Path

print("="*60)
print("Outlook COM Diagnostic Tool")
print("="*60)

# Test 1: Check if pywin32 is installed
print("\n[1] Checking pywin32 installation...")
try:
    import win32com.client
    import pythoncom
    print("    OK - pywin32 is installed")
except ImportError as e:
    print(f"    FAILED - pywin32 not installed: {e}")
    sys.exit(1)

# Test 2: Try to dispatch Outlook
print("\n[2] Testing Outlook.Application dispatch...")
try:
    import win32com.client as win32
    outlook = win32.Dispatch("Outlook.Application")
    print(f"    OK - Outlook connected!")
    print(f"    Version: {outlook.Version}")
except Exception as e:
    print(f"    FAILED - {e}")
    error_code = str(e)

    if "-2147221005" in error_code or "Invalid class string" in error_code:
        print("\n    ** This error means Outlook COM is not registered **")
        print("    ** Outlook may be installed but COM automation is broken **")

# Test 3: Check if Outlook.exe exists
print("\n[3] Checking Outlook.exe installation paths...")
possible_paths = [
    Path("C:/Program Files/Microsoft Office/root/Office16/OUTLOOK.EXE"),
    Path("C:/Program Files (x86)/Microsoft Office/Office16/OUTLOOK.EXE"),
    Path("C:/Program Files (x86)/Microsoft Office/Office15/OUTLOOK.EXE"),
    Path("C:/Program Files/Microsoft Office/Office16/OUTLOOK.EXE"),
    Path("C:/Program Files/Microsoft Office/Office15/OUTLOOK.EXE"),
]

outlook_path = None
for path in possible_paths:
    if path.exists():
        print(f"    FOUND - {path}")
        outlook_path = path
        break
else:
    print("    NOT FOUND - Outlook.exe not found in standard locations")

# Test 4: If Outlook found, show re-registration commands
if outlook_path:
    print("\n[4] Outlook Re-registration Commands")
    print("    Run these commands in Command Prompt AS ADMINISTRATOR:\n")
    outlook_dir = outlook_path.parent
    print(f'    cd "{outlook_dir}"')
    print(f'    outlook.exe /unregserver')
    print(f'    outlook.exe /regserver')
    print()

# Test 5: Check Windows registry for Outlook
print("\n[5] Checking Windows Registry for Outlook COM...")
try:
    result = subprocess.run(
        ['reg', 'query', 'HKCR\\Outlook.Application', '/ve'],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print("    OK - Outlook.Application is registered in registry")
        print(f"    {result.stdout.strip()}")
    else:
        print("    FAILED - Outlook.Application NOT found in registry")
        print("    ** This confirms COM registration is broken **")
except Exception as e:
    print(f"    ERROR checking registry: {e}")

# Summary
print("\n" + "="*60)
print("SUMMARY")
print("="*60)

if outlook_path:
    print("\nOutlook IS installed but COM registration is BROKEN")
    print("\nTO FIX:")
    print("1. Close Outlook if it's running")
    print("2. Open Command Prompt AS ADMINISTRATOR")
    print("3. Run these commands:\n")
    outlook_dir = outlook_path.parent
    print(f'   cd "{outlook_dir}"')
    print(f'   outlook.exe /unregserver')
    print(f'   outlook.exe /regserver')
    print("\n4. Test again with this script")
else:
    print("\nOutlook is NOT installed")
    print("\nTO FIX:")
    print("1. Install Microsoft Office with Outlook")
    print("2. Configure an email account in Outlook")
    print("3. Run this diagnostic script again")

print("\n" + "="*60)
