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
DOWNLOAD_DIR="/tmp/guarddog"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[INFO]${NC} Downloading GuardDog AI deployment script..."

# Create download directory
mkdir -p "$DOWNLOAD_DIR"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# Download the script
if command -v curl &> /dev/null; then
    curl -fsSL "$GITHUB_REPO_URL" -o "$SCRIPT_PATH"
elif command -v wget &> /dev/null; then
    wget -q "$GITHUB_REPO_URL" -O "$SCRIPT_PATH"
else
    echo -e "${RED}[ERROR]${NC} Neither curl nor wget is installed"
    exit 1
fi

# Make executable
chmod +x "$SCRIPT_PATH"

echo -e "${GREEN}[INFO]${NC} Running deployment script..."
echo ""

# Execute with proper stdin/stdout/stderr
exec "$SCRIPT_PATH" "$@"