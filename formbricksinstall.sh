#!/bin/bash

# Formbricks Local Development Setup Script for Blank Debian 12
# Two-Stage Installation Process:
#   Stage 1: Install system dependencies (Docker, NVM, Node.js)
#   Stage 2: Install Formbricks (after reboot/re-login)

set -e  # Exit on any error
set -o pipefail  # Catch errors in pipes

echo "================================================"
echo "Formbricks Development Environment Setup"
echo "For Blank Debian 12 Installation"
echo "================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Track if we started as root
STARTED_AS_ROOT=false
if [ "$EUID" -eq 0 ]; then
    STARTED_AS_ROOT=true
fi

# Get the actual user (even if running with sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# State file to track installation progress
STATE_FILE="$ACTUAL_HOME/.formbricks-setup-state"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_critical() {
    echo -e "\n${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} $1"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}\n"
}

# Function to save state
save_state() {
    echo "$1=true" >> "$STATE_FILE"
}

# Function to check state
check_state() {
    if [ -f "$STATE_FILE" ] && grep -q "^$1=true" "$STATE_FILE"; then
        return 0
    else
        return 1
    fi
}

# Function to handle errors
handle_error() {
    print_error "Error occurred: $1"
    if [ -f "$LOG_FILE" ]; then
        print_error "Check log file: $LOG_FILE"
    fi
    exit 1
}

print_header "Initial System Check"

# Check OS version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    print_success "Detected OS: $PRETTY_NAME"
    
    if [[ "$ID" != "debian" ]]; then
        print_warning "This script is designed for Debian. Detected: $ID"
        print_info "Continuing anyway, but some steps may fail..."
    fi
    
    if [[ "$VERSION_ID" != "12" ]]; then
        print_warning "This script is optimized for Debian 12. Detected: Debian $VERSION_ID"
        print_info "Continuing anyway..."
    fi
else
    print_error "Cannot detect OS version"
    exit 1
fi

# For blank Debian, we need to be root initially to install sudo
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        print_error "sudo is not installed and you're not running as root"
        print_error "Please run this script as root initially: su -c './formbricks-setup.sh'"
        exit 1
    fi
fi

# Create state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
    chown $ACTUAL_USER:$ACTUAL_USER "$STATE_FILE" 2>/dev/null || true
fi

# Create log file
LOG_FILE="$ACTUAL_HOME/formbricks-setup-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"
chown $ACTUAL_USER:$ACTUAL_USER "$LOG_FILE" 2>/dev/null || true
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

print_success "Log file created: $LOG_FILE"

# Determine which stage we're in
print_header "Determining Installation Stage"

# Check if system dependencies are installed
STAGE1_COMPLETE=false
if check_state "STAGE1_COMPLETE"; then
    STAGE1_COMPLETE=true
    print_info "Stage 1 (System Dependencies) already completed"
fi

# Check prerequisites for Stage 2
PREREQUISITES_MET=false
if [ "$STAGE1_COMPLETE" = true ]; then
    print_info "Checking if prerequisites are ready for Stage 2..."
    
    # Test if NVM is actually accessible
    if su - $ACTUAL_USER -c "command -v nvm" &>/dev/null || \
       su - $ACTUAL_USER -c 'bash -l -c "command -v nvm"' &>/dev/null || \
       [ -s "$ACTUAL_HOME/.nvm/nvm.sh" ]; then
        print_success "NVM is accessible"
        
        # Test if node works
        NODE_TEST=$(su - $ACTUAL_USER -c 'bash -l -c "node --version"' 2>/dev/null || echo "FAILED")
        if [[ "$NODE_TEST" != "FAILED" ]]; then
            print_success "Node.js is working: $NODE_TEST"
            PREREQUISITES_MET=true
        else
            print_warning "Node.js is not accessible in user shell"
            print_warning "This usually means you need to logout and login again"
        fi
    else
        print_warning "NVM is not accessible in user shell"
        print_warning "This usually means you need to logout and login again"
    fi
fi

# Decide what to do
if [ "$STAGE1_COMPLETE" = false ]; then
    print_critical "STAGE 1: Installing System Dependencies"
elif [ "$PREREQUISITES_MET" = false ]; then
    print_critical "REBOOT/RE-LOGIN REQUIRED"
    echo ""
    echo "Stage 1 completed, but the environment is not ready yet."
    echo ""
    echo -e "${RED}You MUST do one of the following:${NC}"
    echo ""
    echo "  Option 1 (Recommended): ${BLUE}Reboot the system${NC}"
    echo "    sudo reboot"
    echo ""
    echo "  Option 2: ${BLUE}Logout and login as user '$ACTUAL_USER'${NC}"
    echo "    exit"
    echo "    su - $ACTUAL_USER"
    echo ""
    echo "After reboot/re-login, run this script again:"
    echo "  ${BLUE}./formbricks-setup.sh${NC}"
    echo ""
    echo "The script will automatically continue to Stage 2."
    echo ""
    exit 0
else
    print_critical "STAGE 2: Installing Formbricks"
fi

##########################################
# STAGE 1: System Dependencies
##########################################

if [ "$STAGE1_COMPLETE" = false ]; then
    
    print_header "Installing Core System Tools"
    
    # Update package lists
    if ! check_state "APT_UPDATED"; then
        print_info "Updating package lists..."
        apt update || handle_error "Failed to update package lists"
        print_success "Package lists updated"
        save_state "APT_UPDATED"
    else
        print_success "Package lists already updated"
    fi
    
    # Install sudo if not present
    if ! check_state "SUDO_INSTALLED"; then
        if ! command -v sudo &> /dev/null; then
            print_info "Installing sudo (not present on system)..."
            apt install -y sudo || handle_error "Failed to install sudo"
            print_success "sudo installed"
            
            # Add the actual user to sudo group
            print_info "Adding user '$ACTUAL_USER' to sudo group..."
            usermod -aG sudo $ACTUAL_USER || handle_error "Failed to add user to sudo group"
            print_success "User added to sudo group"
        else
            print_success "sudo already installed"
        fi
        save_state "SUDO_INSTALLED"
    else
        print_success "sudo already installed"
    fi
    
    # Install basic utilities
    if ! check_state "BASIC_UTILS_INSTALLED"; then
        print_info "Installing basic system utilities..."
        BASIC_PACKAGES="curl wget ca-certificates gnupg lsb-release apt-transport-https software-properties-common dirmngr gpg"
        apt install -y $BASIC_PACKAGES || handle_error "Failed to install basic utilities"
        print_success "Basic utilities installed"
        save_state "BASIC_UTILS_INSTALLED"
    else
        print_success "Basic utilities already installed"
    fi
    
    # Install essential development tools
    if ! check_state "DEV_TOOLS_INSTALLED"; then
        print_info "Installing essential development tools..."
        DEV_PACKAGES="git build-essential openssl procps lsof"
        apt install -y $DEV_PACKAGES || handle_error "Failed to install development tools"
        print_success "Development tools installed"
        save_state "DEV_TOOLS_INSTALLED"
    else
        print_success "Development tools already installed"
    fi
    
    print_header "System Verification"
    
    # Check internet connectivity
    print_info "Checking internet connectivity..."
    if ping -c 1 -W 5 google.com &> /dev/null || ping -c 1 -W 5 1.1.1.1 &> /dev/null; then
        print_success "Internet connection available"
    else
        print_error "No internet connection detected"
        exit 1
    fi
    
    # Check available disk space
    print_info "Checking disk space..."
    AVAILABLE_SPACE=$(df -BG $ACTUAL_HOME | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -ge 10 ]; then
        print_success "Sufficient disk space available: ${AVAILABLE_SPACE}GB"
    else
        print_warning "Low disk space. Have ${AVAILABLE_SPACE}GB, recommended 10GB+"
    fi
    
    print_header "Docker Installation"
    
    if ! check_state "DOCKER_INSTALLED"; then
        if ! command -v docker &> /dev/null; then
            print_info "Installing Docker from official repository..."
            
            # Remove conflicting packages
            print_info "Removing any conflicting Docker packages..."
            for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
                apt-get remove -y $pkg 2>/dev/null || true
            done
            
            # Add Docker's official GPG key
            print_info "Adding Docker's official GPG key..."
            install -m 0755 -d /etc/apt/keyrings || handle_error "Failed to create keyrings directory"
            
            if curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; then
                chmod a+r /etc/apt/keyrings/docker.asc
                print_success "Docker GPG key added"
            else
                handle_error "Failed to download Docker GPG key"
            fi
            
            # Add Docker repository
            print_info "Adding Docker repository..."
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              tee /etc/apt/sources.list.d/docker.list > /dev/null || handle_error "Failed to add Docker repository"
            
            # Update package index
            apt-get update || handle_error "Failed to update package index"
            
            # Install Docker
            print_info "Installing Docker Engine and plugins (this may take a few minutes)..."
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "Failed to install Docker"
            
            # Add user to docker group
            usermod -aG docker $ACTUAL_USER || handle_error "Failed to add user to docker group"
            
            # Start and enable Docker
            systemctl enable docker || handle_error "Failed to enable Docker"
            systemctl start docker || handle_error "Failed to start Docker"
            
            # Verify Docker
            if docker version &> /dev/null; then
                print_success "Docker installed and running"
            else
                handle_error "Docker installed but not running"
            fi
            
            save_state "DOCKER_INSTALLED"
        else
            print_success "Docker already installed"
            save_state "DOCKER_INSTALLED"
        fi
    else
        print_success "Docker already installed (skipped)"
    fi
    
    print_header "Node.js Setup with NVM"
    
    if ! check_state "NODEJS_INSTALLED"; then
        # Remove old Node.js versions
        print_info "Removing old Node.js versions if any..."
        apt remove -y nodejs npm 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        
        # Install NVM as the actual user
        print_info "Installing NVM, Node.js v20, and pnpm as user '$ACTUAL_USER'..."
        
        cat > /tmp/install_node_env.sh << 'EOFNODE'
#!/bin/bash
set -e
export HOME=$1
cd $HOME

echo "=== Installing NVM ==="
# Remove old NVM if exists
if [ -d "$HOME/.nvm" ]; then
    rm -rf "$HOME/.nvm"
fi

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Load NVM for this script
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Verify NVM loaded
if ! command -v nvm &> /dev/null; then
    echo "ERROR: NVM installation failed"
    exit 1
fi
echo "NVM installed successfully"

echo "=== Installing Node.js v20 ==="
nvm install 20
nvm use 20
nvm alias default 20

# Verify Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js installation failed"
    exit 1
fi
echo "Node.js installed: $(node --version)"

echo "=== Installing pnpm ==="
npm install -g pnpm

# Verify pnpm
if ! command -v pnpm &> /dev/null; then
    echo "ERROR: pnpm installation failed"
    exit 1
fi
echo "pnpm installed: $(pnpm --version)"

echo "=== Verifying installations ==="
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "pnpm: $(pnpm --version)"

# Test in a fresh shell (like after login)
bash -l -c "node --version && npm --version && pnpm --version" || {
    echo "WARNING: Tools not accessible in login shell yet"
    echo "This is normal - they will work after logout/login"
}

echo "=== Installation complete ==="
EOFNODE

        chmod +x /tmp/install_node_env.sh
        
        if su - $ACTUAL_USER -c "/tmp/install_node_env.sh $ACTUAL_HOME"; then
            print_success "Node.js environment installed"
            save_state "NODEJS_INSTALLED"
        else
            handle_error "Failed to install Node.js environment"
        fi
        
        rm /tmp/install_node_env.sh
    else
        print_success "Node.js environment already installed (skipped)"
    fi
    
    # Mark Stage 1 as complete
    save_state "STAGE1_COMPLETE"
    
    print_header "Stage 1 Complete!"
    
    print_critical "REBOOT OR RE-LOGIN REQUIRED"
    echo ""
    echo "System dependencies have been installed successfully!"
    echo ""
    echo "Changes made:"
    echo "  • Installed Docker and added '$ACTUAL_USER' to docker group"
    echo "  • Installed NVM, Node.js v20, and pnpm"
    echo "  • Modified shell configuration files (~/.bashrc)"
    echo ""
    echo -e "${RED}CRITICAL: You MUST do one of the following:${NC}"
    echo ""
    echo "  ${GREEN}Option 1 (RECOMMENDED):${NC} ${BLUE}Reboot the system${NC}"
    echo "    sudo reboot"
    echo ""
    echo "  ${GREEN}Option 2:${NC} ${BLUE}Logout and login as user '$ACTUAL_USER'${NC}"
    if [ "$STARTED_AS_ROOT" = true ]; then
        echo "    exit        # Exit root session"
    fi
    echo "    exit        # Logout"
    echo "    # Then SSH/login again as $ACTUAL_USER"
    echo ""
    echo "After reboot/re-login, continue installation:"
    echo "  ${BLUE}./formbricks-setup.sh${NC}"
    echo ""
    echo "The script will automatically continue to Stage 2 (Formbricks installation)."
    echo ""
    
    exit 0
fi

##########################################
# STAGE 2: Formbricks Installation
##########################################

print_header "Verifying Prerequisites for Stage 2"

# Run comprehensive checks
CHECKS_PASSED=0
CHECKS_FAILED=0

# Check Docker
print_info "Checking Docker..."
if docker version &> /dev/null; then
    print_success "Docker is working"
    ((CHECKS_PASSED++))
else
    print_error "Docker is not working"
    ((CHECKS_FAILED++))
fi

# Check Docker as user
print_info "Checking Docker permissions for user..."
if su - $ACTUAL_USER -c "docker version" &> /dev/null; then
    print_success "User can run Docker commands"
    ((CHECKS_PASSED++))
else
    print_error "User cannot run Docker commands (group permissions not applied)"
    print_error "You must logout and login again"
    ((CHECKS_FAILED++))
fi

# Check NVM
print_info "Checking NVM availability..."
NVM_CHECK=$(su - $ACTUAL_USER -c 'bash -l -c "command -v nvm"' 2>/dev/null || echo "FAILED")
if [[ "$NVM_CHECK" != "FAILED" ]]; then
    print_success "NVM is available: $NVM_CHECK"
    ((CHECKS_PASSED++))
else
    print_error "NVM is not available in user's shell"
    ((CHECKS_FAILED++))
fi

# Check Node.js
print_info "Checking Node.js..."
NODE_CHECK=$(su - $ACTUAL_USER -c 'bash -l -c "node --version"' 2>/dev/null || echo "FAILED")
if [[ "$NODE_CHECK" != "FAILED" ]]; then
    print_success "Node.js is working: $NODE_CHECK"
    ((CHECKS_PASSED++))
else
    print_error "Node.js is not available"
    ((CHECKS_FAILED++))
fi

# Check npm
print_info "Checking npm..."
NPM_CHECK=$(su - $ACTUAL_USER -c 'bash -l -c "npm --version"' 2>/dev/null || echo "FAILED")
if [[ "$NPM_CHECK" != "FAILED" ]]; then
    print_success "npm is working: v$NPM_CHECK"
    ((CHECKS_PASSED++))
else
    print_error "npm is not available"
    ((CHECKS_FAILED++))
fi

# Check pnpm
print_info "Checking pnpm..."
PNPM_CHECK=$(su - $ACTUAL_USER -c 'bash -l -c "pnpm --version"' 2>/dev/null || echo "FAILED")
if [[ "$PNPM_CHECK" != "FAILED" ]]; then
    print_success "pnpm is working: v$PNPM_CHECK"
    ((CHECKS_PASSED++))
else
    print_error "pnpm is not available"
    ((CHECKS_FAILED++))
fi

# Check Git
print_info "Checking Git..."
if git --version &> /dev/null; then
    print_success "Git is available: $(git --version)"
    ((CHECKS_PASSED++))
else
    print_error "Git is not available"
    ((CHECKS_FAILED++))
fi

echo ""
echo "Prerequisite checks: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
echo ""

if [ $CHECKS_FAILED -gt 0 ]; then
    print_error "Prerequisites not met! Cannot continue to Stage 2."
    echo ""
    print_critical "YOU MUST REBOOT OR RE-LOGIN"
    echo ""
    echo "The most common cause is that you haven't logged out and back in"
    echo "after Stage 1 installation."
    echo ""
    echo "Please do one of:"
    echo "  1. Reboot the system: ${BLUE}sudo reboot${NC}"
    echo "  2. Logout and login again as user '$ACTUAL_USER'"
    echo ""
    echo "Then run this script again."
    echo ""
    exit 1
fi

print_success "All prerequisites met! Proceeding with Formbricks installation..."

print_header "Formbricks Repository Setup"

WORKSPACE_DIR="$ACTUAL_HOME/formbricks"

if ! check_state "FORMBRICKS_INSTALLED"; then
    
    cat > /tmp/setup_formbricks.sh << 'EOFFB'
#!/bin/bash
set -e
export HOME=$1
WORKSPACE_DIR="$HOME/formbricks"

# Load NVM properly
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Verify we have the tools
if ! command -v node &> /dev/null || ! command -v pnpm &> /dev/null; then
    echo "ERROR: Node.js or pnpm not available"
    exit 1
fi

cd $HOME

if [ -d "$WORKSPACE_DIR" ]; then
    echo "Formbricks directory exists, updating..."
    cd "$WORKSPACE_DIR"
    if [ -d ".git" ]; then
        git pull || echo "Could not pull (OK if you have local changes)"
    fi
else
    echo "Cloning Formbricks repository..."
    git clone https://github.com/formbricks/formbricks
    cd "$WORKSPACE_DIR"
fi

echo "Installing dependencies with pnpm..."
pnpm install

echo "Setting up environment file..."
if [ -f ".env" ]; then
    cp .env .env.backup
    echo "Backed up existing .env"
fi

if [ ! -f ".env.example" ]; then
    echo "ERROR: .env.example not found"
    exit 1
fi

cp .env.example .env

echo "Generating secrets..."
sed -i '/^ENCRYPTION_KEY=/c\ENCRYPTION_KEY='$(openssl rand -hex 32) .env
sed -i '/^NEXTAUTH_SECRET=/c\NEXTAUTH_SECRET='$(openssl rand -hex 32) .env
sed -i '/^CRON_SECRET=/c\CRON_SECRET='$(openssl rand -hex 32) .env

echo "Verifying secrets..."
if grep -q "ENCRYPTION_KEY=.\{64\}" .env && \
   grep -q "NEXTAUTH_SECRET=.\{64\}" .env && \
   grep -q "CRON_SECRET=.\{64\}" .env; then
    echo "All secrets generated successfully"
else
    echo "ERROR: Secret generation failed"
    exit 1
fi

echo "Formbricks setup complete!"
EOFFB

    chmod +x /tmp/setup_formbricks.sh
    
    if su - $ACTUAL_USER -c "/tmp/setup_formbricks.sh $ACTUAL_HOME"; then
        print_success "Formbricks installed and configured"
        save_state "FORMBRICKS_INSTALLED"
    else
        handle_error "Failed to setup Formbricks"
    fi
    
    rm /tmp/setup_formbricks.sh
else
    print_success "Formbricks already installed (skipped)"
fi

print_header "Final Verification Tests"

TESTS_PASSED=0
TESTS_FAILED=0

# Test Formbricks structure
print_info "Test: Formbricks repository structure"
if [ -f "$WORKSPACE_DIR/package.json" ] && [ -f "$WORKSPACE_DIR/pnpm-workspace.yaml" ]; then
    print_success "Repository structure verified"
    ((TESTS_PASSED++))
else
    print_error "Repository structure invalid"
    ((TESTS_FAILED++))
fi

# Test node_modules
print_info "Test: Dependencies installed"
if [ -d "$WORKSPACE_DIR/node_modules" ] && [ "$(ls -A $WORKSPACE_DIR/node_modules)" ]; then
    print_success "Dependencies installed"
    ((TESTS_PASSED++))
else
    print_error "Dependencies missing"
    ((TESTS_FAILED++))
fi

# Test .env file
print_info "Test: Environment configuration"
if [ -f "$WORKSPACE_DIR/.env" ] && grep -q "ENCRYPTION_KEY=.\{64\}" "$WORKSPACE_DIR/.env"; then
    print_success "Environment configured"
    ((TESTS_PASSED++))
else
    print_error "Environment configuration failed"
    ((TESTS_FAILED++))
fi

# Test port 3000
print_info "Test: Port 3000 availability"
if ! lsof -i :3000 &> /dev/null; then
    print_success "Port 3000 is available"
    ((TESTS_PASSED++))
else
    print_warning "Port 3000 is in use"
    ((TESTS_PASSED++))
fi

print_header "Creating Start Script"

cat > "$ACTUAL_HOME/start-formbricks.sh" << 'EOFSTART'
#!/bin/bash
# Formbricks Quick Start Script

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Verify environment
if ! command -v pnpm &> /dev/null; then
    echo "ERROR: pnpm not found. Did you source your shell config?"
    echo "Try: source ~/.bashrc"
    exit 1
fi

# Navigate to formbricks
cd $HOME/formbricks || {
    echo "ERROR: formbricks directory not found"
    exit 1
}

echo "Starting Formbricks development server..."
echo "Access it at: http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop"
echo ""

pnpm dev
EOFSTART

chmod +x "$ACTUAL_HOME/start-formbricks.sh"
chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/start-formbricks.sh"
print_success "Start script created: ~/start-formbricks.sh"

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║                                                ║"
echo "║       🎉  INSTALLATION COMPLETE!  🎉          ║"
echo "║                                                ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Installation Summary:"
echo "  ✓ Docker: $(docker --version | cut -d' ' -f3 | sed 's/,//')"
echo "  ✓ Node.js: $NODE_CHECK"
echo "  ✓ pnpm: v$PNPM_CHECK"
echo "  ✓ Formbricks: Ready at $WORKSPACE_DIR"
echo ""
echo "Tests: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo ""
echo "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Start Formbricks:"
echo "   ${BLUE}./start-formbricks.sh${NC}"
echo ""
echo "   Or manually:"
echo "   ${BLUE}cd formbricks${NC}"
echo "   ${BLUE}pnpm dev${NC}"
echo ""
echo "2. Access Formbricks:"
echo "   ${BLUE}http://localhost:3000${NC}"
echo ""
echo "3. On first access, create your admin account"
echo ""
echo "Logs saved to: $LOG_FILE"
echo ""
