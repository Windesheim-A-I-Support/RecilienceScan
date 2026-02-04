#!/bin/bash
# ResilienceScan GUI Launcher
# Performs system checks before launching the GUI

echo "═══════════════════════════════════════════════════════════"
echo "ResilienceScan Control Center - Launcher"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python 3.8 or higher."
    exit 1
fi

echo "✅ Python3 found: $(python3 --version)"

# Run system check
echo ""
echo "Running system diagnostics..."
echo ""

python3 gui_system_check.py

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️ System check completed with warnings."
    echo "   The GUI will launch, but some features may not work."
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Launching ResilienceScan GUI..."
echo "═══════════════════════════════════════════════════════════"
echo ""

# Launch GUI
python3 ResilienceScanGUI.py

echo ""
echo "GUI closed. Goodbye!"
