#!/bin/bash

#############################################
# GuardDog AI - Installation Script
# This script downloads and runs the latest
# GuardDog AI deployment script from GitHub
#############################################

set -e

# Configuration
GITHUB_REPO_URL="https://raw.githubusercontent.com/guarddog-dev/GUARDDOG-AI-Documentation/main/Deployment%20scripts/gdai_deploy.sh"
SCRIPT_NAME="gdai_deploy.sh"
DOWNLOAD_DIR="/tmp/guarddog"
LOG_FILE="/tmp/guarddog_install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#############################################
# Logging Functions
#############################################

log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

#############################################
# Utility Functions
#############################################

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

cleanup() {
    if [ -d "$DOWNLOAD_DIR" ]; then
        log "Cleaning up temporary files..."
        rm -rf "$DOWNLOAD_DIR"
    fi
}

#############################################
# Main Functions
#############################################

print_banner() {
    echo ""
    echo "=========================================="
    echo "   GuardDog AI - Installation Script"
    echo "=========================================="
    echo ""
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check for curl or wget
    if command -v curl &> /dev/null; then
        DOWNLOAD_TOOL="curl"
        log "Found curl for downloading"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_TOOL="wget"
        log "Found wget for downloading"
    else
        log_error "Neither curl nor wget is installed. Please install one of them."
        exit 1
    fi
    
    # Check for bash
    check_command "bash"
    
    log "All prerequisites met"
}

download_script() {
    log_step "Downloading latest GuardDog AI deployment script..."
    
    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
    
    local download_path="$DOWNLOAD_DIR/$SCRIPT_NAME"
    
    # Download the script
    if [ "$DOWNLOAD_TOOL" = "curl" ]; then
        if curl -fsSL "$GITHUB_REPO_URL" -o "$download_path"; then
            log "Successfully downloaded deployment script"
        else
            log_error "Failed to download script from GitHub"
            cleanup
            exit 1
        fi
    else
        if wget -q "$GITHUB_REPO_URL" -O "$download_path"; then
            log "Successfully downloaded deployment script"
        else
            log_error "Failed to download script from GitHub"
            cleanup
            exit 1
        fi
    fi
    
    # Make the script executable
    chmod +x "$download_path"
    
    echo "$download_path"
}

run_deployment_script() {
    local script_path="$1"
    
    log_step "Running GuardDog AI deployment script..."
    echo ""
    
    # Execute the downloaded script
    bash "$script_path"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log "Deployment completed successfully"
    else
        log_error "Deployment script exited with code $exit_code"
        cleanup
        exit $exit_code
    fi
}

#############################################
# Main Execution
#############################################

main() {
    # Initialize log file
    echo "GuardDog AI Installation - $(date)" > "$LOG_FILE"
    
    print_banner
    
    # Check prerequisites
    check_prerequisites
    
    # Download the latest script
    script_path=$(download_script)
    
    # Run the deployment script
    run_deployment_script "$script_path"
    
    # Cleanup
    cleanup
    
    echo ""
    log "Installation process completed!"
    log "Log file saved to: $LOG_FILE"
    echo ""
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"