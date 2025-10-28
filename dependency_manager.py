"""
Cross-Platform Dependency Manager
Checks and installs required software for ResilienceScan
Supports both Windows and Linux
"""

import subprocess
import sys
import platform
import os
from pathlib import Path
import urllib.request
import tempfile


class DependencyManager:
    """Manage software dependencies across platforms"""

    def __init__(self):
        self.platform = platform.system()  # 'Windows', 'Linux', 'Darwin'
        self.is_windows = self.platform == 'Windows'
        self.is_linux = self.platform == 'Linux'
        self.is_mac = self.platform == 'Darwin'

        self.checks = []

    def check_all(self):
        """Check all dependencies"""
        self.checks = []

        self.check_python()
        self.check_python_packages()
        self.check_r()
        self.check_quarto()
        self.check_git()

        return self.checks

    def check_python(self):
        """Check Python installation"""
        version = sys.version_info
        version_str = f"{version.major}.{version.minor}.{version.micro}"

        check = {
            'name': 'Python',
            'required': True,
            'installed': True,
            'version': version_str,
            'meets_requirements': version.major >= 3 and version.minor >= 8,
            'install_command': self.get_python_install_command(),
            'check_command': 'python3 --version' if not self.is_windows else 'python --version'
        }

        self.checks.append(check)
        return check

    def check_python_packages(self):
        """Check required Python packages"""
        required_packages = {
            'pandas': 'pip install pandas',
            'openpyxl': 'pip install openpyxl',
            'xlrd': 'pip install xlrd'
        }

        for package, install_cmd in required_packages.items():
            try:
                __import__(package)
                check = {
                    'name': f'Python Package: {package}',
                    'required': True,
                    'installed': True,
                    'version': self.get_package_version(package),
                    'meets_requirements': True,
                    'install_command': install_cmd,
                    'check_command': f'pip show {package}'
                }
            except ImportError:
                check = {
                    'name': f'Python Package: {package}',
                    'required': True,
                    'installed': False,
                    'version': 'Not installed',
                    'meets_requirements': False,
                    'install_command': install_cmd,
                    'check_command': f'pip show {package}'
                }

            self.checks.append(check)

        return self.checks

    def check_r(self):
        """Check R installation"""
        try:
            if self.is_windows:
                # Check common Windows R installation paths
                r_paths = [
                    r'C:\Program Files\R\R-*\bin\R.exe',
                    r'C:\Program Files\R\R-*\bin\x64\R.exe',
                ]
                r_found = False
                r_version = None

                import glob
                for pattern in r_paths:
                    matches = glob.glob(pattern)
                    if matches:
                        r_found = True
                        # Try to get version
                        try:
                            result = subprocess.run(
                                [matches[0], '--version'],
                                capture_output=True,
                                text=True,
                                timeout=5
                            )
                            if result.returncode == 0:
                                r_version = result.stdout.split('\n')[0]
                        except:
                            pass
                        break

                if not r_found:
                    # Try R from PATH
                    result = subprocess.run(['R', '--version'],
                                          capture_output=True,
                                          text=True,
                                          timeout=5)
                    r_found = result.returncode == 0
                    if r_found:
                        r_version = result.stdout.split('\n')[0]

            else:
                # Linux/Mac
                result = subprocess.run(['R', '--version'],
                                      capture_output=True,
                                      text=True,
                                      timeout=5)
                r_found = result.returncode == 0
                if r_found:
                    r_version = result.stdout.split('\n')[0]

            check = {
                'name': 'R',
                'required': True,
                'installed': r_found,
                'version': r_version if r_version else 'Unknown',
                'meets_requirements': r_found,
                'install_command': self.get_r_install_command(),
                'check_command': 'R --version',
                'download_url': 'https://www.r-project.org/'
            }

        except (FileNotFoundError, subprocess.TimeoutExpired):
            check = {
                'name': 'R',
                'required': True,
                'installed': False,
                'version': 'Not installed',
                'meets_requirements': False,
                'install_command': self.get_r_install_command(),
                'check_command': 'R --version',
                'download_url': 'https://www.r-project.org/'
            }

        self.checks.append(check)
        return check

    def check_quarto(self):
        """Check Quarto installation"""
        try:
            result = subprocess.run(['quarto', '--version'],
                                  capture_output=True,
                                  text=True,
                                  timeout=5)

            if result.returncode == 0:
                version = result.stdout.strip()
                check = {
                    'name': 'Quarto',
                    'required': True,
                    'installed': True,
                    'version': version,
                    'meets_requirements': True,
                    'install_command': self.get_quarto_install_command(),
                    'check_command': 'quarto --version',
                    'download_url': 'https://quarto.org/docs/get-started/'
                }
            else:
                raise FileNotFoundError

        except (FileNotFoundError, subprocess.TimeoutExpired):
            check = {
                'name': 'Quarto',
                'required': True,
                'installed': False,
                'version': 'Not installed',
                'meets_requirements': False,
                'install_command': self.get_quarto_install_command(),
                'check_command': 'quarto --version',
                'download_url': 'https://quarto.org/docs/get-started/'
            }

        self.checks.append(check)
        return check

    def check_git(self):
        """Check Git installation (optional)"""
        try:
            result = subprocess.run(['git', '--version'],
                                  capture_output=True,
                                  text=True,
                                  timeout=5)

            if result.returncode == 0:
                version = result.stdout.strip().replace('git version ', '')
                check = {
                    'name': 'Git',
                    'required': False,
                    'installed': True,
                    'version': version,
                    'meets_requirements': True,
                    'install_command': self.get_git_install_command(),
                    'check_command': 'git --version'
                }
            else:
                raise FileNotFoundError

        except (FileNotFoundError, subprocess.TimeoutExpired):
            check = {
                'name': 'Git',
                'required': False,
                'installed': False,
                'version': 'Not installed',
                'meets_requirements': False,
                'install_command': self.get_git_install_command(),
                'check_command': 'git --version'
            }

        self.checks.append(check)
        return check

    # ========== Install Command Generators ==========

    def get_python_install_command(self):
        """Get Python installation command"""
        if self.is_windows:
            return {
                'manual': 'Download from https://www.python.org/downloads/',
                'command': None
            }
        elif self.is_linux:
            return {
                'manual': None,
                'command': 'sudo apt-get update && sudo apt-get install python3 python3-pip'
            }
        elif self.is_mac:
            return {
                'manual': None,
                'command': 'brew install python3'
            }

    def get_r_install_command(self):
        """Get R installation command"""
        if self.is_windows:
            return {
                'manual': 'Download from https://cran.r-project.org/bin/windows/base/',
                'command': None
            }
        elif self.is_linux:
            return {
                'manual': None,
                'command': 'sudo apt-get update && sudo apt-get install r-base r-base-dev'
            }
        elif self.is_mac:
            return {
                'manual': None,
                'command': 'brew install r'
            }

    def get_quarto_install_command(self):
        """Get Quarto installation command"""
        if self.is_windows:
            return {
                'manual': 'Download from https://quarto.org/docs/get-started/',
                'command': None,
                'installer_url': 'https://quarto.org/download/latest/QuartoInstaller.exe'
            }
        elif self.is_linux:
            return {
                'manual': 'Download from https://quarto.org/docs/get-started/',
                'command': 'wget https://quarto.org/download/latest/quarto-linux-amd64.deb && sudo dpkg -i quarto-linux-amd64.deb',
                'installer_url': 'https://quarto.org/download/latest/quarto-linux-amd64.deb'
            }
        elif self.is_mac:
            return {
                'manual': None,
                'command': 'brew install quarto'
            }

    def get_git_install_command(self):
        """Get Git installation command"""
        if self.is_windows:
            return {
                'manual': 'Download from https://git-scm.com/download/win',
                'command': None
            }
        elif self.is_linux:
            return {
                'manual': None,
                'command': 'sudo apt-get update && sudo apt-get install git'
            }
        elif self.is_mac:
            return {
                'manual': None,
                'command': 'brew install git'
            }

    # ========== Installation Methods ==========

    def install_package(self, package_name):
        """Install a Python package"""
        try:
            result = subprocess.run(
                [sys.executable, '-m', 'pip', 'install', package_name],
                capture_output=True,
                text=True,
                timeout=120
            )

            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr
            }

        except Exception as e:
            return {
                'success': False,
                'output': '',
                'error': str(e)
            }

    def install_r(self):
        """Install R (platform specific)"""
        cmd_info = self.get_r_install_command()

        if cmd_info['command']:
            try:
                # For Linux/Mac with package manager
                result = subprocess.run(
                    cmd_info['command'],
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=300
                )

                return {
                    'success': result.returncode == 0,
                    'output': result.stdout,
                    'error': result.stderr,
                    'requires_admin': True
                }

            except Exception as e:
                return {
                    'success': False,
                    'output': '',
                    'error': str(e),
                    'requires_admin': True
                }
        else:
            # Windows - needs manual download
            return {
                'success': False,
                'output': '',
                'error': 'Please download and install manually',
                'download_url': cmd_info['manual'],
                'requires_manual': True
            }

    def install_quarto(self):
        """Install Quarto (platform specific)"""
        cmd_info = self.get_quarto_install_command()

        if cmd_info['command']:
            try:
                result = subprocess.run(
                    cmd_info['command'],
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=300
                )

                return {
                    'success': result.returncode == 0,
                    'output': result.stdout,
                    'error': result.stderr,
                    'requires_admin': self.is_linux
                }

            except Exception as e:
                return {
                    'success': False,
                    'output': '',
                    'error': str(e),
                    'requires_admin': self.is_linux
                }
        else:
            # Windows - needs manual download or provide download link
            return {
                'success': False,
                'output': '',
                'error': 'Please download and install manually',
                'download_url': cmd_info.get('manual'),
                'installer_url': cmd_info.get('installer_url'),
                'requires_manual': True
            }

    # ========== Utility Methods ==========

    def get_package_version(self, package_name):
        """Get version of a Python package"""
        try:
            module = __import__(package_name)
            if hasattr(module, '__version__'):
                return module.__version__
            return 'Unknown'
        except:
            return 'Unknown'

    def get_platform_info(self):
        """Get platform information"""
        return {
            'system': self.platform,
            'is_windows': self.is_windows,
            'is_linux': self.is_linux,
            'is_mac': self.is_mac,
            'architecture': platform.machine(),
            'python_version': sys.version
        }

    def can_auto_install(self, check):
        """Check if software can be auto-installed"""
        if check['name'].startswith('Python Package'):
            return True
        elif check['name'] in ['R', 'Quarto', 'Git']:
            cmd_info = check.get('install_command', {})
            return cmd_info.get('command') is not None
        return False

    def get_summary(self):
        """Get summary of all checks"""
        total = len(self.checks)
        installed = sum(1 for c in self.checks if c['installed'])
        required = sum(1 for c in self.checks if c['required'])
        required_installed = sum(1 for c in self.checks
                                if c['required'] and c['installed'])

        return {
            'total': total,
            'installed': installed,
            'required': required,
            'required_installed': required_installed,
            'all_required_met': required == required_installed,
            'ready_for_use': required == required_installed
        }


if __name__ == "__main__":
    # Test the dependency manager
    manager = DependencyManager()

    print("=" * 70)
    print(f"Platform: {manager.platform}")
    print("=" * 70)
    print()

    checks = manager.check_all()

    for check in checks:
        status = "[OK]" if check['installed'] else "[ERROR]"
        required = "[REQUIRED]" if check['required'] else "[OPTIONAL]"
        print(f"{status} {check['name']:<30} {required}")
        print(f"   Version: {check['version']}")
        if not check['installed'] and check.get('install_command'):
            cmd = check['install_command']
            if isinstance(cmd, dict):
                if cmd.get('command'):
                    print(f"   Install: {cmd['command']}")
                if cmd.get('manual'):
                    print(f"   Manual: {cmd['manual']}")
        print()

    summary = manager.get_summary()
    print("=" * 70)
    print(f"Summary: {summary['required_installed']}/{summary['required']} required dependencies met")
    print(f"Ready for use: {summary['ready_for_use']}")
    print("=" * 70)
