@echo off
REM Resilience Report Generator - Installation Launcher
REM This batch file launches the PowerShell installer script

echo.
echo ========================================
echo  RESILIENCE REPORT GENERATOR INSTALLER
echo ========================================
echo.
echo This will install all necessary dependencies for the
echo Resilience Report Generator project.
echo.
echo Requirements:
echo - Windows 10/11
echo - Internet connection
echo - Administrator privileges
echo.
echo The installation may take 10-30 minutes depending on
echo your system and internet connection.
echo.
pause

REM Check if PowerShell is available
powershell -Command "exit" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not available on this system.
    echo Please install PowerShell and try again.
    pause
    exit /b 1
)

REM Run the PowerShell installer script
echo Starting installation...
echo.

powershell -ExecutionPolicy Bypass -File "install_environment.ps1"

REM Check if the installation was successful
if %errorlevel% equ 0 (
    echo.
    echo Installation completed successfully!
    echo.
    echo You can now use the Resilience Report Generator.
    echo Check the README.md for usage instructions.
) else (
    echo.
    echo Installation encountered some issues.
    echo Please check the output above for details.
    echo.
    echo You may need to:
    echo 1. Run this installer as Administrator
    echo 2. Check your internet connection
    echo 3. Install components manually
)

echo.
pause