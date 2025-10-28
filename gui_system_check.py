"""
System Check Module for ResilienceScan GUI
Validates all dependencies and environment setup
"""

import subprocess
import sys
from pathlib import Path
import importlib.util


class SystemChecker:
    """Check system dependencies and environment"""

    def __init__(self, root_dir):
        self.root_dir = Path(root_dir)
        self.checks = []
        self.errors = []
        self.warnings = []

    def check_all(self):
        """Run all system checks"""
        self.checks = []
        self.errors = []
        self.warnings = []

        # Critical checks
        self.check_python_version()
        self.check_python_packages()
        self.check_r_installation()
        self.check_quarto_installation()
        self.check_files()
        self.check_data()
        self.check_directories()

        return len(self.errors) == 0

    def check_python_version(self):
        """Check Python version"""
        version = sys.version_info
        if version.major >= 3 and version.minor >= 8:
            self.add_check("[OK] Python version", f"{version.major}.{version.minor}.{version.micro}", "OK")
        else:
            self.add_error("[ERROR] Python version", f"{version.major}.{version.minor}.{version.micro}",
                          "Python 3.8+ required")

    def check_python_packages(self):
        """Check required Python packages"""
        required_packages = [
            'pandas',
            'tkinter',
            'pathlib',
            'subprocess'
        ]

        for package in required_packages:
            try:
                if package == 'tkinter':
                    import tkinter
                else:
                    __import__(package)
                self.add_check(f"[OK] Package: {package}", "Installed", "OK")
            except ImportError:
                self.add_error(f"[ERROR] Package: {package}", "Not found",
                              f"Install with: pip install {package}")

    def check_r_installation(self):
        """Check R installation"""
        try:
            result = subprocess.run(['R', '--version'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                version = result.stdout.split('\n')[0]
                self.add_check("[OK] R", version, "OK")
            else:
                self.add_warning("[WARNING] R", "Not accessible", "R required for report generation")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            self.add_warning("[WARNING] R", "Not found", "Install R from https://www.r-project.org/")

    def check_quarto_installation(self):
        """Check Quarto installation"""
        try:
            result = subprocess.run(['quarto', '--version'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                version = result.stdout.strip()
                self.add_check(f"[OK] Quarto", f"v{version}", "OK")

                # Check Quarto can render
                result = subprocess.run(
                    ['quarto', 'check'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                if result.returncode == 0:
                    self.add_check("[OK] Quarto check", "Passed", "OK")
                else:
                    self.add_warning("[WARNING] Quarto check", "Failed", "Run 'quarto check' manually")
            else:
                self.add_error("[ERROR] Quarto", "Not working", "Reinstall Quarto")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            self.add_error("[ERROR] Quarto", "Not found", "Install from https://quarto.org/")

    def check_files(self):
        """Check required files exist"""
        required_files = [
            ('ResilienceReport.qmd', 'Main report template'),
            ('generate_all_reports.py', 'Generation script'),
            ('clean_data.py', 'Data processing script'),
            ('send_email.py', 'Email distribution script'),
            ('config.yml', 'Configuration file'),
        ]

        for filename, description in required_files:
            filepath = self.root_dir / filename
            if filepath.exists():
                size = filepath.stat().st_size / 1024  # KB
                self.add_check(f"[OK] File: {filename}", f"{size:.1f} KB", description)
            else:
                self.add_error(f"[ERROR] File: {filename}", "Not found", description)

    def check_data(self):
        """Check data files"""
        data_dir = self.root_dir / "data"
        cleaned_master = data_dir / "cleaned_master.csv"

        if data_dir.exists():
            self.add_check("[OK] Data directory", "Exists", "OK")

            if cleaned_master.exists():
                try:
                    import pandas as pd
                    df = pd.read_csv(cleaned_master)
                    self.add_check(f"[OK] cleaned_master.csv",
                                  f"{len(df)} rows, {len(df.columns)} columns",
                                  "Ready for processing")
                except Exception as e:
                    self.add_error("[ERROR] cleaned_master.csv", "Cannot read", str(e))
            else:
                self.add_warning("[WARNING] cleaned_master.csv", "Not found",
                               "Run clean_data.py first")
        else:
            self.add_error("[ERROR] Data directory", "Not found", "Create data/ folder")

    def check_directories(self):
        """Check required directories"""
        required_dirs = [
            ('reports', 'PDF output directory'),
            ('img', 'Logo images'),
            ('logs', 'Log files'),
            ('templates', 'Template archives'),
        ]

        for dirname, description in required_dirs:
            dirpath = self.root_dir / dirname
            if dirpath.exists():
                file_count = len(list(dirpath.glob('*')))
                self.add_check(f"[OK] Directory: {dirname}", f"{file_count} files", description)
            else:
                self.add_warning(f"[WARNING] Directory: {dirname}", "Not found", description)

    def add_check(self, item, status, description):
        """Add successful check"""
        self.checks.append({
            'type': 'success',
            'item': item,
            'status': status,
            'description': description
        })

    def add_error(self, item, status, description):
        """Add error"""
        self.checks.append({
            'type': 'error',
            'item': item,
            'status': status,
            'description': description
        })
        self.errors.append(f"{item}: {description}")

    def add_warning(self, item, status, description):
        """Add warning"""
        self.checks.append({
            'type': 'warning',
            'item': item,
            'status': status,
            'description': description
        })
        self.warnings.append(f"{item}: {description}")

    def get_report(self):
        """Get formatted check report"""
        report = "=" * 70 + "\n"
        report += "SYSTEM CHECK REPORT\n"
        report += "=" * 70 + "\n\n"

        for check in self.checks:
            icon = check['item'].split()[0]
            item = ' '.join(check['item'].split()[1:])
            report += f"{icon} {item:<40} {check['status']}\n"
            report += f"   → {check['description']}\n\n"

        report += "=" * 70 + "\n"
        report += f"Total Checks: {len(self.checks)}\n"
        report += f"Errors: {len(self.errors)}\n"
        report += f"Warnings: {len(self.warnings)}\n"
        report += "=" * 70 + "\n"

        if self.errors:
            report += "\n[WARNING] ERRORS FOUND:\n"
            for error in self.errors:
                report += f"  • {error}\n"

        if self.warnings:
            report += "\n[WARNING] WARNINGS:\n"
            for warning in self.warnings:
                report += f"  • {warning}\n"

        return report

    def is_ready_for_generation(self):
        """Check if system is ready for report generation"""
        critical_checks = [
            'Quarto',
            'ResilienceReport.qmd',
            'cleaned_master.csv'
        ]

        for check in self.checks:
            for critical in critical_checks:
                if critical in check['item'] and check['type'] == 'error':
                    return False

        return True

    def is_ready_for_email(self):
        """Check if system is ready for email distribution"""
        critical_checks = [
            'send_email.py',
            'cleaned_master.csv'
        ]

        for check in self.checks:
            for critical in critical_checks:
                if critical in check['item'] and check['type'] == 'error':
                    return False

        return True


if __name__ == "__main__":
    # Test the checker
    checker = SystemChecker(Path(__file__).parent)
    checker.check_all()
    print(checker.get_report())
