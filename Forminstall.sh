#!/bin/bash

# STAGE 2: Install Formbricks
# Following official guide: https://formbricks.com/docs/development/local-setup/linux
# Run as: formbrickuser (NOT root)

set -e

echo "========================================"
echo "STAGE 2: Installing Formbricks"
echo "========================================"
echo ""

# Check we're NOT root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do NOT run this as root!"
    echo "Run as: su - formbrickuser"
    echo "Then: ./stage2.sh"
    exit 1
fi

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "Checking prerequisites..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found"
    echo "Try: source ~/.bashrc"
    exit 1
fi
echo "✓ Node.js: $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm not found"
    exit 1
fi
echo "✓ npm: $(npm --version)"

# Check pnpm
if ! command -v pnpm &> /dev/null; then
    echo "ERROR: pnpm not found"
    echo "Try: source ~/.bashrc"
    exit 1
fi
echo "✓ pnpm: $(pnpm --version)"

# Check git
if ! command -v git &> /dev/null; then
    echo "ERROR: git not found"
    exit 1
fi
echo "✓ git: $(git --version)"

# Check openssl
if ! command -v openssl &> /dev/null; then
    echo "ERROR: openssl not found"
    exit 1
fi
echo "✓ openssl: available"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: docker not found"
    exit 1
fi
echo "✓ docker: $(docker --version)"

echo ""
echo "All prerequisites OK!"
echo ""
echo "Following official Formbricks guide..."
echo ""

# Step 1: Clone the project & move into the directory
echo "[1/5] Cloning Formbricks repository..."
if [ -d "formbricks" ]; then
    echo "Directory 'formbricks' already exists"
    echo "Remove it? (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        rm -rf formbricks
        echo "Removed old directory"
    else
        echo "Keeping existing directory"
        cd formbricks
        git pull || echo "Could not pull (OK if you have local changes)"
    fi
else
    git clone https://github.com/formbricks/formbricks
fi

cd formbricks || exit 1
echo "✓ Repository ready"

# Step 2: Setup NodeJS with nvm
echo ""
echo "[2/5] Setting up Node.js version..."
nvm use
echo "✓ Node.js version set"

# Step 3: Install NodeJS packages via pnpm
echo ""
echo "[3/5] Installing dependencies with pnpm..."
echo "This will take 5-10 minutes..."
pnpm install
echo "✓ Dependencies installed"

# Step 4: Create a .env file based on .env.example
echo ""
echo "[4/5] Creating .env file..."
if [ -f ".env" ]; then
    echo "Backing up existing .env..."
    cp .env .env.backup
fi
cp .env.example .env
echo "✓ .env file created"

# Step 5: Generate & set the secret values
echo ""
echo "[5/5] Generating secret keys..."
sed -i '/^ENCRYPTION_KEY=/c\ENCRYPTION_KEY='$(openssl rand -hex 32) .env
sed -i '/^NEXTAUTH_SECRET=/c\NEXTAUTH_SECRET='$(openssl rand -hex 32) .env
sed -i '/^CRON_SECRET=/c\CRON_SECRET='$(openssl rand -hex 32) .env
echo "✓ Secret keys generated"

echo ""
echo "========================================"
echo "STAGE 2 COMPLETE"
echo "========================================"
echo ""
echo "Formbricks is installed!"
echo ""
echo "To start Formbricks:"
echo "  cd formbricks"
echo "  pnpm go"
echo ""
echo "Then access at: http://localhost:3000"
echo ""
