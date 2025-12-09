#!/bin/bash

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Configuration
GITHUB_REPO_URL="https://raw.githubusercontent.com/guarddog-dev/GUARDDOG-AI-Documentation/main/Deployment%20scripts/gdai_deploy.sh"
SCRIPT_NAME="gdai_deploy.sh"
INSTALL_DIR="/usr/local/bin"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "   GuardDog AI - Installation Script"
echo "=========================================="
echo ""

echo -e "${GREEN}[INFO]${NC} Downloading GuardDog AI deployment script..."

# Download the script
if command -v curl &> /dev/null; then
    curl -fsSL "$GITHUB_REPO_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
elif command -v wget &> /dev/null; then
    wget -q "$GITHUB_REPO_URL" -O "$INSTALL_DIR/$SCRIPT_NAME"
else
    echo -e "${YELLOW}[ERROR]${NC} Neither curl nor wget is installed"
    exit 1
fi

# Make executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo -e "${GREEN}[SUCCESS]${NC} Deployment script downloaded to: $INSTALL_DIR/$SCRIPT_NAME"
echo ""
echo "=========================================="
echo "   Next Steps"
echo "=========================================="
echo ""
echo -e "${BLUE}To deploy GuardDog AI, run the following command:${NC}"
echo ""
echo -e "  ${GREEN}sudo $SCRIPT_NAME${NC}"
echo ""
echo "The deployment script will guide you through the setup process."
echo ""