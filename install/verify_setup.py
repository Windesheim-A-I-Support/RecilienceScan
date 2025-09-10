#!/usr/bin/env python3
"""
Resilience Report Generator - Setup Verification Script
This script verifies that all dependencies are properly installed and configured.
WORKS FROM ANY DIRECTORY - automatically finds project root.
"""

import subprocess
import sys
import os
import importlib.util
from pathlib import Path

def find_project_root():
    """Find the project root directory by looking for key files"""
    current_dir = Path(__file__).parent.absolute()
    
    # Key files that indicate project root
    key_files = ["example_3.qmd", "clean_data.py", "generate_reports.py"]
    
    # Search current dir and parent directories
    search_dirs = [
        current_dir,
        current_dir.parent,
        current_dir.parent.parent
    ]
    
    for directory in search_dirs:
        found_files = sum(1 for f in key_files if (directory / f).exists())
        if found_files >= 2:  # Found most key files
            return directory
    
    # Default to current directory if not found
    print(f"⚠ Could not auto-detect project root. Using: {current_dir}")
    return current_dir

# Change to project root
PROJECT_ROOT = find_project_root()
os.chdir(PROJECT_ROOT)
print(f"ℹ Working from project root: {PROJECT_ROOT}")

def print_header(title):
    """Print a formatted header"""
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60)

def print_success(message):
    """Print success message in green"""
    print(f"✓ {message}")

def print_error(message):
    """Print error message in red"""
    print(f"✗ {message}")

def print_warning(message):
    """Print warning message in yellow"""
    print(f"⚠ {message}")

def print_info(message):
    """Print info message in blue"""
    print(f"ℹ {message}")

def check_command(command, description):
    """Check if a command is available"""
    try:
        result = subprocess.run([command, "--version"], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip().split('\n')[0]
            print_success(f"{description}: {version}")
            return True
        else:
            print_error(f"{description}: Command failed")
            return False
    except FileNotFoundError:
        print_error(f"{description}: Not found")
        return False
    except subprocess.TimeoutExpired:
        print_error(f"{description}: Command timed out")
        return False
    except Exception as e:
        print_error(f"{description}: {str(e)}")
        return False

def check_python_package(package_name):
    """Check if a Python package is installed"""
    try:
        spec = importlib.util.find_spec(package_name)
        if spec is not None:
            print_success(f"Python package '{package_name}': Installed")
            return True
        else:
            print_error(f"Python package '{package_name}': Not found")
            return False
    except Exception as e:
        print_error(f"Python package '{package_name}': Error - {str(e)}")
        return False

def check_r_packages():
    """Check if required R packages are installed"""
    r_packages = [
        "readr", "dplyr", "stringr", "tidyr", "ggplot2", 
        "fmsb", "scales", "rmarkdown", "knitr"
    ]
    
    r_script = f"""
    packages <- c({', '.join([f'"{pkg}"' for pkg in r_packages])})
    installed <- sapply(packages, function(pkg) {{
        if (require(pkg, character.only = TRUE, quietly = TRUE)) {{
            cat(paste("SUCCESS:", pkg, "\\n"))
            return(TRUE)
        }} else {{
            cat(paste("MISSING:", pkg, "\\n"))
            return(FALSE)
        }}
    }})
    """
    
    try:
        result = subprocess.run(["R", "--vanilla", "--slave", "-e", r_script],
                              capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            success_count = 0
            for line in lines:
                if line.startswith("SUCCESS:"):
                    package = line.replace("SUCCESS: ", "")
                    print_success(f"R package '{package}': Installed")
                    success_count += 1
                elif line.startswith("MISSING:"):
                    package = line.replace("MISSING: ", "")
                    print_error(f"R package '{package}': Not found")
            
            return success_count == len(r_packages)
        else:
            print_error("Failed to check R packages")
            return False
            
    except Exception as e:
        print_error(f"R packages check failed: {str(e)}")
        return False

def check_file_structure():
    """Check if required files and directories exist"""
    required_items = [
        ("data/", "Data directory"),
        ("reports/", "Reports output directory"),
        ("img/", "Images directory"),
        ("tex/", "LaTeX files directory"),
        ("fonts/", "Fonts directory"),
        ("example_3.qmd", "Quarto template"),
        ("clean_data.py", "Data cleaning script"),
        ("generate_reports.py", "Report generation script"),
        ("send_emails.py", "Email sending script"),
        ("references.bib", "Bibliography file")
    ]
    
    all_exist = True
    for item_path, description in required_items:
        if os.path.exists(item_path):
            print_success(f"{description}: Found")
        else:
            print_warning(f"{description}: Not found ({item_path})")
            all_exist = False
    
    return all_exist

def check_font_installation():
    """Check if custom font is installed"""
    font_path = Path("fonts/QTDublinIrish.otf")
    
    if font_path.exists():
        print_success("Custom font file: Found in fonts directory")
        
        # Try to check if font is installed system-wide (Windows)
        if os.name == 'nt':
            system_font_path = Path(os.environ['WINDIR']) / "Fonts" / "QTDublinIrish.otf"
            if system_font_path.exists():
                print_success("Custom font: Installed system-wide")
                return True
            else:
                print_warning("Custom font: Not installed system-wide")
                print_info("  You may need to install the font manually or restart your computer")
                return False
        else:
            print_info("Custom font: Cannot verify system installation on this OS")
            return True
    else:
        print_error("Custom font file: Not found in fonts directory")
        return False

def check_quarto_extensions():
    """Check if Quarto extensions are installed"""
    try:
        result = subprocess.run(["quarto", "list", "extensions"],
                              capture_output=True, text=True, timeout=15)
        
        if result.returncode == 0:
            if "nmfs-opensci/quarto_titlepages" in result.stdout:
                print_success("Quarto title pages extension: Installed")
                return True
            else:
                print_warning("Quarto title pages extension: Not found")
                print_info("  Run: quarto install extension nmfs-opensci/quarto_titlepages")
                return False
        else:
            print_warning("Could not check Quarto extensions")
            return False
            
    except Exception as e:
        print_warning(f"Quarto extensions check failed: {str(e)}")
        return False

def main():
    """Main verification function"""
    print_header("RESILIENCE REPORT GENERATOR - SETUP VERIFICATION")
    print_info("This script will verify that all dependencies are properly installed.")
    
    results = {}
    
    # Check core tools
    print_header("CORE TOOLS")
    results['python'] = check_command("python", "Python")
    results['r'] = check_command("R", "R")
    results['quarto'] = check_command("quarto", "Quarto")
    
    # Check Python packages
    print_header("PYTHON PACKAGES")
    python_packages = ["pandas", "win32com.client" if os.name == 'nt' else "smtplib"]
    results['python_packages'] = all(check_python_package(pkg) for pkg in python_packages)
    
    # Check R packages
    print_header("R PACKAGES")
    results['r_packages'] = check_r_packages()
    
    # Check file structure
    print_header("PROJECT FILES")
    results['files'] = check_file_structure()
    
    # Check font installation
    print_header("CUSTOM FONT")
    results['font'] = check_font_installation()
    
    # Check Quarto extensions
    print_header("QUARTO EXTENSIONS")
    results['extensions'] = check_quarto_extensions()
    
    # Summary
    print_header("VERIFICATION SUMMARY")
    
    all_good = True
    for check_name, result in results.items():
        if result:
            print_success(f"{check_name.replace('_', ' ').title()}: OK")
        else:
            print_error(f"{check_name.replace('_', ' ').title()}: Issues found")
            all_good = False
    
    print("\n" + "="*60)
    if all_good:
        print_success("ALL CHECKS PASSED! Your system is ready to use the Resilience Report Generator.")
        print_info("\nNext steps:")
        print("  1. Place your data file in the data/ directory")
        print("  2. Run: python clean_data.py")
        print("  3. Run: python generate_reports.py")
        print("  4. (Optional) Run: python send_emails.py")
    else:
        print_warning("SOME ISSUES WERE FOUND. Please address the issues above before using the system.")
        print_info("\nFor help:")
        print("  - Check the README.md file")
        print("  - Re-run the installer: run_installer.bat")
        print("  - Install missing components manually")
    
    print("="*60)
    
    return 0 if all_good else 1

if __name__ == "__main__":
    sys.exit(main())