#!/bin/bash

# STAGE 1: Install ALL Dependencies for Formbricks
# For BLANK Debian 12 - Assumes NOTHING is installed
# Run this as ROOT: ./stage1.sh

set -e

echo "========================================"
echo "STAGE 1: Installing ALL Dependencies"
echo "========================================"
echo ""

# Must be run as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Run: su -c './stage1.sh'"
    exit 1
fi

# Use hardcoded user
ACTUAL_USER="formbrickuser"

# Create user if doesn't exist
if ! id "$ACTUAL_USER" &>/dev/null; then
    echo "Creating user: $ACTUAL_USER"
    useradd -m -s /bin/bash $ACTUAL_USER
    echo "$ACTUAL_USER:formbricks" | chpasswd
    echo "✓ User created (password: formbricks)"
fi

ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo "Setting up for user: $ACTUAL_USER"
echo "Home directory: $ACTUAL_HOME"
echo ""

# Update package lists
echo "[1/10] Updating package lists..."
apt update

# Install sudo if not present
echo "[2/10] Installing sudo..."
apt install -y sudo

# Add user to sudo group (whether user was just created or already existed)
echo "[3/10] Adding user to sudo group..."
usermod -aG sudo $ACTUAL_USER
echo "✓ User added to sudo group"

# Install basic tools
echo "[4/10] Installing basic tools..."
apt install -y curl wget git ca-certificates gnupg lsb-release

# Install build tools (needed for Node.js native modules)
echo "[5/10] Installing build tools..."
apt install -y build-essential

# Install openssl (needed for generating secrets)
echo "[6/10] Installing openssl..."
apt install -y openssl

# Install Docker
echo "[7/10] Installing Docker..."

# Remove old versions
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y $pkg 2>/dev/null || true
done

# Add Docker's GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
usermod -aG docker $ACTUAL_USER

# Start Docker
systemctl enable docker
systemctl start docker

echo "✓ Docker installed"

# Install NVM, Node.js, and pnpm as the actual user
echo "[8/10] Installing NVM and Node.js as user $ACTUAL_USER..."

su - $ACTUAL_USER << 'EOFNVM'
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js v20
nvm install 20
nvm use 20
nvm alias default 20

# Verify
node --version
npm --version
EOFNVM

echo "✓ NVM and Node.js installed"

# Install pnpm as the actual user
echo "[9/10] Installing pnpm as user $ACTUAL_USER..."

su - $ACTUAL_USER << 'EOFPNPM'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

npm install -g pnpm

# Verify
pnpm --version
EOFPNPM

echo "✓ pnpm installed"

# Verify everything
echo "[10/10] Verifying installations..."
echo ""

# Check Docker
if docker --version &> /dev/null; then
    echo "✓ Docker: $(docker --version)"
else
    echo "✗ Docker: FAILED"
fi

# Check git
if git --version &> /dev/null; then
    echo "✓ Git: $(git --version)"
else
    echo "✗ Git: FAILED"
fi

# Check openssl
if openssl version &> /dev/null; then
    echo "✓ OpenSSL: $(openssl version)"
else
    echo "✗ OpenSSL: FAILED"
fi

# Check Node.js (as user)
NODE_VER=$(su - $ACTUAL_USER -c 'bash -l -c "node --version"' 2>/dev/null || echo "FAILED")
if [ "$NODE_VER" != "FAILED" ]; then
    echo "✓ Node.js: $NODE_VER"
else
    echo "✗ Node.js: FAILED"
fi

# Check pnpm (as user)
PNPM_VER=$(su - $ACTUAL_USER -c 'bash -l -c "pnpm --version"' 2>/dev/null || echo "FAILED")
if [ "$PNPM_VER" != "FAILED" ]; then
    echo "✓ pnpm: $PNPM_VER"
else
    echo "✗ pnpm: FAILED"
fi

echo ""
echo "========================================"
echo "STAGE 1 COMPLETE"
echo "========================================"
echo ""
echo "CRITICAL: You MUST reboot now!"
echo ""
echo "Run: reboot"
echo ""
echo "After reboot, login as: $ACTUAL_USER"
echo "Then run Stage 2 to install Formbricks"
echo ""
