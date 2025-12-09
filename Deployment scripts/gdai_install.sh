# Fixed version of install script
#!/bin/bash

#############################################
# GuardDog AI - Installation Script
# This script downloads and runs the latest
# GuardDog AI deployment script from GitHub
#############################################

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
LOG_FILE="/var/log/guarddog_install.log"

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
    
    SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"
    
    # Download the script
    if [ "$DOWNLOAD_TOOL" = "curl" ]; then
        if curl -fsSL "$GITHUB_REPO_URL" -o "$SCRIPT_PATH" 2>&1 | tee -a "$LOG_FILE"; then
            log "Successfully downloaded deployment script to $SCRIPT_PATH"
        else
            log_error "Failed to download script from GitHub"
            exit 1
        fi
    else
        if wget -q "$GITHUB_REPO_URL" -O "$SCRIPT_PATH" 2>&1 | tee -a "$LOG_FILE"; then
            log "Successfully downloaded deployment script to $SCRIPT_PATH"
        else
            log_error "Failed to download script from GitHub"
            exit 1
        fi
    fi
    
    # Verify the file exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        log_error "Downloaded script not found at $SCRIPT_PATH"
        exit 1
    fi
    
    # Make the script executable
    chmod +x "$SCRIPT_PATH"
    log "Script is ready at: $SCRIPT_PATH"
}

run_deployment_script() {
    log_step "Running GuardDog AI deployment script with sudo..."
    echo ""
    
    # Verify script exists before running
    if [ ! -f "$SCRIPT_PATH" ]; then
        log_error "Script not found at $SCRIPT_PATH"
        exit 1
    fi
    
    # Execute the downloaded script with sudo (already running as root)
    bash "$SCRIPT_PATH"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log "Deployment completed successfully"
    else
        log_error "Deployment script exited with code $exit_code"
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
    download_script
    
    # Run the deployment script
    run_deployment_script
    
    # Cleanup after successful deployment
    cleanup
    
    echo ""
    log "Installation process completed!"
    log "Log file saved to: $LOG_FILE"
    echo ""
}

# Run main function
main "$@"