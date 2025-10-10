#!/bin/bash

# Formbricks Interactive TUI Setup for Blank Debian 12
# Two-Stage Installation with Beautiful Terminal Interface

set -e
set -o pipefail

# Color codes for fallback mode
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Track if we started as root
STARTED_AS_ROOT=false
if [ "$EUID" -eq 0 ]; then
    STARTED_AS_ROOT=true
fi

# Get the actual user
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# State and log files
STATE_FILE="$ACTUAL_HOME/.formbricks-setup-state"
LOG_FILE="$ACTUAL_HOME/formbricks-setup-$(date +%Y%m%d-%H%M%S).log"

# TUI mode flag
USE_TUI=true

# Dialog dimensions
DIALOG_HEIGHT=20
DIALOG_WIDTH=70

# Initialize logging
exec 3>&1
exec 4>&2
exec 1>>"$LOG_FILE" 2>&1

###########################################
# TUI Functions
###########################################

check_dialog() {
    if command -v dialog &> /dev/null; then
        return 0
    else
        return 1
    fi
}

install_dialog() {
    echo "Installing dialog for interactive interface..." >&3
    apt update >/dev/null 2>&1
    apt install -y dialog >/dev/null 2>&1
    if check_dialog; then
        return 0
    else
        USE_TUI=false
        return 1
    fi
}

tui_msgbox() {
    local title="$1"
    local message="$2"
    local height="${3:-15}"
    local width="${4:-60}"
    
    if [ "$USE_TUI" = true ]; then
        dialog --title "$title" --msgbox "$message" $height $width 2>&3
    else
        echo -e "\n${BLUE}=== $title ===${NC}" >&3
        echo -e "$message" >&3
        echo "" >&3
    fi
}

tui_infobox() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-50}"
    
    if [ "$USE_TUI" = true ]; then
        dialog --title "$title" --infobox "$message" $height $width 2>&3
        sleep 2
    else
        echo -e "${YELLOW}➜ $message${NC}" >&3
    fi
}

tui_yesno() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-50}"
    
    if [ "$USE_TUI" = true ]; then
        dialog --title "$title" --yesno "$message" $height $width 2>&3
        return $?
    else
        echo -e "\n${YELLOW}$title${NC}" >&3
        echo -e "$message" >&3
        read -p "Continue? (y/n): " -n 1 -r >&3
        echo "" >&3
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

tui_gauge() {
    local title="$1"
    local percent="$2"
    local message="$3"
    
    if [ "$USE_TUI" = true ]; then
        echo "$percent" | dialog --title "$title" --gauge "$message" 10 60 0 2>&3
    else
        echo -e "${CYAN}[$percent%] $message${NC}" >&3
    fi
}

tui_progress() {
    local title="$1"
    shift
    local steps=("$@")
    local total=${#steps[@]}
    local current=0
    
    for step in "${steps[@]}"; do
        current=$((current + 1))
        local percent=$((current * 100 / total))
        
        if [ "$USE_TUI" = true ]; then
            echo "XXX"
            echo "$percent"
            echo "$step"
            echo "XXX"
            sleep 1
        else
            echo -e "${CYAN}[$percent%] $step${NC}" >&3
        fi
    done | if [ "$USE_TUI" = true ]; then
        dialog --title "$title" --gauge "Processing..." 10 70 0 2>&3
    else
        cat >&3
    fi
}

tui_checklist_results() {
    local title="$1"
    local message="$2"
    shift 2
    local items=("$@")
    
    if [ "$USE_TUI" = true ]; then
        local display=""
        for item in "${items[@]}"; do
            display="$display$item\n"
        done
        dialog --title "$title" --msgbox "$message\n\n$display" 20 70 2>&3
    else
        echo -e "\n${BLUE}=== $title ===${NC}" >&3
        echo -e "$message\n" >&3
        for item in "${items[@]}"; do
            echo -e "$item" >&3
        done
        echo "" >&3
    fi
}

tui_error() {
    local message="$1"
    if [ "$USE_TUI" = true ]; then
        dialog --title "Error" --msgbox "$message\n\nCheck log: $LOG_FILE" 12 60 2>&3
    else
        echo -e "\n${RED}✗ ERROR: $message${NC}" >&3
        echo -e "Check log: $LOG_FILE" >&3
    fi
    exit 1
}

tui_clear() {
    if [ "$USE_TUI" = true ]; then
        clear >&3
    fi
}

###########################################
# Helper Functions
###########################################

save_state() {
    echo "$1=true" >> "$STATE_FILE"
}

check_state() {
    if [ -f "$STATE_FILE" ] && grep -q "^$1=true" "$STATE_FILE"; then
        return 0
    else
        return 1
    fi
}

run_with_progress() {
    local title="$1"
    local message="$2"
    shift 2
    local command="$@"
    
    tui_infobox "$title" "$message"
    
    if eval "$command"; then
        return 0
    else
        return 1
    fi
}

###########################################
# Main Setup
###########################################

# Create state and log files
touch "$STATE_FILE" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true
chown $ACTUAL_USER:$ACTUAL_USER "$STATE_FILE" 2>/dev/null || true
chown $ACTUAL_USER:$ACTUAL_USER "$LOG_FILE" 2>/dev/null || true

# Check if we need to install dialog
if ! check_dialog; then
    if [ "$EUID" -eq 0 ] || command -v sudo &> /dev/null; then
        install_dialog || USE_TUI=false
    else
        USE_TUI=false
    fi
fi

# Welcome Screen
if [ "$USE_TUI" = true ]; then
    dialog --title "Formbricks Setup" --msgbox "Welcome to Formbricks Interactive Setup!\n\nThis installer will guide you through setting up Formbricks on Debian 12.\n\nFeatures:\n• Two-stage installation\n• Docker + Node.js environment\n• Complete Formbricks setup\n• Interactive progress tracking\n\nPress ENTER to continue..." 18 60 2>&3
    tui_clear
fi

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_INFO="$PRETTY_NAME"
else
    tui_error "Cannot detect OS version"
fi

# Check if root or sudo available
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        tui_error "sudo is not installed and you're not root.\n\nPlease run as root: su -c './formbricks-setup.sh'"
    fi
fi

# Determine stage
STAGE1_COMPLETE=false
PREREQUISITES_MET=false

if check_state "STAGE1_COMPLETE"; then
    STAGE1_COMPLETE=true
    
    # Check prerequisites
    PREREQ_CHECKS=""
    PREREQ_PASS=0
    PREREQ_FAIL=0
    
    # Check Docker
    if docker version &> /dev/null && su - $ACTUAL_USER -c "docker version" &> /dev/null; then
        PREREQ_CHECKS="$PREREQ_CHECKS✓ Docker: Working\n"
        ((PREREQ_PASS++))
    else
        PREREQ_CHECKS="$PREREQ_CHECKS✗ Docker: Not accessible\n"
        ((PREREQ_FAIL++))
    fi
    
    # Check Node.js
    NODE_TEST=$(su - $ACTUAL_USER -c 'bash -l -c "node --version"' 2>/dev/null || echo "FAILED")
    if [[ "$NODE_TEST" != "FAILED" ]]; then
        PREREQ_CHECKS="$PREREQ_CHECKS✓ Node.js: $NODE_TEST\n"
        ((PREREQ_PASS++))
    else
        PREREQ_CHECKS="$PREREQ_CHECKS✗ Node.js: Not accessible\n"
        ((PREREQ_FAIL++))
    fi
    
    # Check pnpm
    PNPM_TEST=$(su - $ACTUAL_USER -c 'bash -l -c "pnpm --version"' 2>/dev/null || echo "FAILED")
    if [[ "$PNPM_TEST" != "FAILED" ]]; then
        PREREQ_CHECKS="$PREREQ_CHECKS✓ pnpm: v$PNPM_TEST\n"
        ((PREREQ_PASS++))
        PREREQUISITES_MET=true
    else
        PREREQ_CHECKS="$PREREQ_CHECKS✗ pnpm: Not accessible\n"
        ((PREREQ_FAIL++))
    fi
fi

###########################################
# Stage Decision
###########################################

if [ "$STAGE1_COMPLETE" = false ]; then
    STAGE="1"
    tui_msgbox "Installation Stage" "STAGE 1: System Dependencies\n\nThis stage will install:\n• Basic system tools (sudo, curl, git)\n• Docker and Docker Compose\n• NVM, Node.js v20, and pnpm\n\nAfter completion, you MUST reboot or re-login.\n\nDetected OS: $OS_INFO\nUser: $ACTUAL_USER" 18 65
elif [ "$PREREQUISITES_MET" = false ]; then
    tui_msgbox "Reboot Required" "Stage 1 is complete, but prerequisites are not ready yet.\n\nPrerequisite Status:\n$PREREQ_CHECKS\nPassed: $PREREQ_PASS | Failed: $PREREQ_FAIL\n\nYou MUST:\n1. Reboot the system (recommended)\n   OR\n2. Logout and login as user '$ACTUAL_USER'\n\nThen run this script again to continue to Stage 2." 20 65
    exit 0
else
    STAGE="2"
    tui_msgbox "Installation Stage" "STAGE 2: Formbricks Setup\n\nPrerequisites verified!\n\nThis stage will:\n• Clone Formbricks repository\n• Install dependencies\n• Configure environment\n• Create start scripts\n\nPrerequisite Status:\n$PREREQ_CHECKS" 18 65
fi

###########################################
# STAGE 1: System Dependencies
###########################################

if [ "$STAGE" = "1" ]; then
    
    # System update
    if ! check_state "APT_UPDATED"; then
        run_with_progress "System Update" "Updating package lists..." "apt update"
        save_state "APT_UPDATED"
    fi
    
    # Install sudo
    if ! check_state "SUDO_INSTALLED"; then
        if ! command -v sudo &> /dev/null; then
            tui_progress "Installing sudo" \
                "Installing sudo package..." \
                "Adding user to sudo group..." \
                "Configuring permissions..."
            
            apt install -y sudo
            usermod -aG sudo $ACTUAL_USER
            save_state "SUDO_INSTALLED"
        else
            save_state "SUDO_INSTALLED"
        fi
    fi
    
    # Install basic utilities
    if ! check_state "BASIC_UTILS_INSTALLED"; then
        tui_progress "Basic Utilities" \
            "Installing curl and wget..." \
            "Installing certificates..." \
            "Installing GPG tools..." \
            "Configuring repositories..."
        
        apt install -y curl wget ca-certificates gnupg lsb-release apt-transport-https software-properties-common dirmngr gpg
        save_state "BASIC_UTILS_INSTALLED"
    fi
    
    # Install development tools
    if ! check_state "DEV_TOOLS_INSTALLED"; then
        tui_progress "Development Tools" \
            "Installing Git..." \
            "Installing build tools..." \
            "Installing OpenSSL..." \
            "Installing system utilities..."
        
        apt install -y git build-essential openssl procps lsof
        save_state "DEV_TOOLS_INSTALLED"
    fi
    
    # Docker installation
    if ! check_state "DOCKER_INSTALLED"; then
        if ! command -v docker &> /dev/null; then
            tui_progress "Docker Installation" \
                "Removing conflicting packages..." \
                "Adding Docker GPG key..." \
                "Adding Docker repository..." \
                "Updating package lists..." \
                "Installing Docker Engine..." \
                "Installing Docker Compose..." \
                "Configuring Docker service..." \
                "Adding user to docker group..."
            
            # Remove conflicts
            for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
                apt-get remove -y $pkg 2>/dev/null || true
            done
            
            # Add Docker repo
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            usermod -aG docker $ACTUAL_USER
            systemctl enable docker
            systemctl start docker
            
            if docker version &> /dev/null; then
                save_state "DOCKER_INSTALLED"
            else
                tui_error "Docker installation failed"
            fi
        else
            save_state "DOCKER_INSTALLED"
        fi
    fi
    
    # Node.js setup
    if ! check_state "NODEJS_INSTALLED"; then
        tui_progress "Node.js Environment" \
            "Removing old Node.js versions..." \
            "Downloading NVM installer..." \
            "Installing NVM..." \
            "Installing Node.js v20..." \
            "Configuring Node.js..." \
            "Installing pnpm..." \
            "Verifying installation..."
        
        apt remove -y nodejs npm 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        
        cat > /tmp/install_node_env.sh << 'EOFNODE'
#!/bin/bash
set -e
export HOME=$1
cd $HOME

# Remove old NVM
rm -rf "$HOME/.nvm" 2>/dev/null || true

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js
nvm install 20
nvm use 20
nvm alias default 20

# Install pnpm
npm install -g pnpm

# Verify
node --version && npm --version && pnpm --version
EOFNODE

        chmod +x /tmp/install_node_env.sh
        
        if su - $ACTUAL_USER -c "/tmp/install_node_env.sh $ACTUAL_HOME"; then
            save_state "NODEJS_INSTALLED"
            rm /tmp/install_node_env.sh
        else
            rm /tmp/install_node_env.sh
            tui_error "Node.js installation failed"
        fi
    fi
    
    # Mark Stage 1 complete
    save_state "STAGE1_COMPLETE"
    
    # Get installed versions
    DOCKER_VER=$(docker --version 2>/dev/null | cut -d' ' -f3 | sed 's/,//' || echo "Unknown")
    
    # Stage 1 complete message
    tui_msgbox "Stage 1 Complete!" "System dependencies installed successfully!\n\nInstalled:\n✓ Docker $DOCKER_VER\n✓ Docker Compose Plugin\n✓ NVM + Node.js v20\n✓ pnpm\n✓ Git and build tools\n\nIMPORTANT: You MUST now:\n1. Reboot (recommended): sudo reboot\n   OR\n2. Logout and login as '$ACTUAL_USER'\n\nAfter reboot/re-login, run this script again.\nIt will automatically continue to Stage 2." 22 65
    
    exit 0
fi

###########################################
# STAGE 2: Formbricks Installation
###########################################

if [ "$STAGE" = "2" ]; then
    
    WORKSPACE_DIR="$ACTUAL_HOME/formbricks"
    
    # Clone and setup Formbricks
    if ! check_state "FORMBRICKS_INSTALLED"; then
        
        tui_progress "Formbricks Setup" \
            "Preparing workspace..." \
            "Cloning repository..." \
            "Installing dependencies (this may take several minutes)..." \
            "Creating environment file..." \
            "Generating security keys..." \
            "Configuring application..." \
            "Finalizing setup..."
        
        cat > /tmp/setup_formbricks.sh << 'EOFFB'
#!/bin/bash
set -e
export HOME=$1
WORKSPACE_DIR="$HOME/formbricks"

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

cd $HOME

# Clone or update
if [ -d "$WORKSPACE_DIR" ]; then
    cd "$WORKSPACE_DIR"
    git pull 2>/dev/null || true
else
    git clone https://github.com/formbricks/formbricks
    cd "$WORKSPACE_DIR"
fi

# Install dependencies
pnpm install

# Setup environment
if [ -f ".env" ]; then
    cp .env .env.backup
fi

cp .env.example .env

# Generate secrets
sed -i '/^ENCRYPTION_KEY=/c\ENCRYPTION_KEY='$(openssl rand -hex 32) .env
sed -i '/^NEXTAUTH_SECRET=/c\NEXTAUTH_SECRET='$(openssl rand -hex 32) .env
sed -i '/^CRON_SECRET=/c\CRON_SECRET='$(openssl rand -hex 32) .env

# Verify
grep -q "ENCRYPTION_KEY=.\{64\}" .env || exit 1
EOFFB

        chmod +x /tmp/setup_formbricks.sh
        
        if su - $ACTUAL_USER -c "/tmp/setup_formbricks.sh $ACTUAL_HOME"; then
            save_state "FORMBRICKS_INSTALLED"
            rm /tmp/setup_formbricks.sh
        else
            rm /tmp/setup_formbricks.sh
            tui_error "Formbricks installation failed"
        fi
    fi
    
    # Create start script
    cat > "$ACTUAL_HOME/start-formbricks.sh" << 'EOFSTART'
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v pnpm &> /dev/null; then
    echo "ERROR: pnpm not found. Try: source ~/.bashrc"
    exit 1
fi

cd $HOME/formbricks || exit 1

echo "Starting Formbricks..."
echo "Access at: http://localhost:3000"
echo ""
pnpm dev
EOFSTART

    chmod +x "$ACTUAL_HOME/start-formbricks.sh"
    chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/start-formbricks.sh"
    
    # Run verification tests
    tui_infobox "Verification" "Running final verification tests..."
    sleep 2
    
    TESTS_RESULT=""
    TESTS_PASS=0
    TESTS_FAIL=0
    
    # Test 1: Repository structure
    if [ -f "$WORKSPACE_DIR/package.json" ]; then
        TESTS_RESULT="$TESTS_RESULT✓ Repository structure\n"
        ((TESTS_PASS++))
    else
        TESTS_RESULT="$TESTS_RESULT✗ Repository structure\n"
        ((TESTS_FAIL++))
    fi
    
    # Test 2: Dependencies
    if [ -d "$WORKSPACE_DIR/node_modules" ]; then
        TESTS_RESULT="$TESTS_RESULT✓ Dependencies installed\n"
        ((TESTS_PASS++))
    else
        TESTS_RESULT="$TESTS_RESULT✗ Dependencies missing\n"
        ((TESTS_FAIL++))
    fi
    
    # Test 3: Environment
    if [ -f "$WORKSPACE_DIR/.env" ] && grep -q "ENCRYPTION_KEY=.\{64\}" "$WORKSPACE_DIR/.env"; then
        TESTS_RESULT="$TESTS_RESULT✓ Environment configured\n"
        ((TESTS_PASS++))
    else
        TESTS_RESULT="$TESTS_RESULT✗ Environment config\n"
        ((TESTS_FAIL++))
    fi
    
    # Test 4: Start script
    if [ -x "$ACTUAL_HOME/start-formbricks.sh" ]; then
        TESTS_RESULT="$TESTS_RESULT✓ Start script created\n"
        ((TESTS_PASS++))
    else
        TESTS_RESULT="$TESTS_RESULT✗ Start script\n"
        ((TESTS_FAIL++))
    fi
    
    # Test 5: Port availability
    if ! lsof -i :3000 &> /dev/null; then
        TESTS_RESULT="$TESTS_RESULT✓ Port 3000 available\n"
        ((TESTS_PASS++))
    else
        TESTS_RESULT="$TESTS_RESULT✗ Port 3000 in use\n"
        ((TESTS_FAIL++))
    fi
    
    # Final success message
    if [ $TESTS_FAIL -eq 0 ]; then
        tui_msgbox "🎉 Installation Complete!" "Formbricks is ready to use!\n\nVerification Tests:\n$TESTS_RESULT\nResults: $TESTS_PASS passed, $TESTS_FAIL failed\n\nNext Steps:\n\n1. Start Formbricks:\n   ./start-formbricks.sh\n\n2. Open browser:\n   http://localhost:3000\n\n3. Create your admin account\n\nLog file: $LOG_FILE" 24 65
    else
        tui_msgbox "Installation Complete (with warnings)" "Formbricks installed but some tests failed.\n\nVerification Tests:\n$TESTS_RESULT\nResults: $TESTS_PASS passed, $TESTS_FAIL failed\n\nYou can try to start anyway:\n./start-formbricks.sh\n\nLog file: $LOG_FILE" 22 65
    fi
    
    tui_clear
    
    # Print final message to console
    echo "" >&3
    echo "╔════════════════════════════════════════════════╗" >&3
    echo "║      🎉  FORMBRICKS INSTALLATION COMPLETE! 🎉  ║" >&3
    echo "╚════════════════════════════════════════════════╝" >&3
    echo "" >&3
    echo "Start Formbricks:  ./start-formbricks.sh" >&3
    echo "Access at:         http://localhost:3000" >&3
    echo "" >&3
fi
