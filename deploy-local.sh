#!/bin/bash

# Deploy script for web-performance-project1-initial
# This script deploys the application to local environment following the template2 structure

set -e  # Exit on any error

# Configuration
PROJECT_NAME="web-performance-project1-initial"
DEPLOY_BASE_DIR="$(cd .. && pwd)/template2"  # jenkins-ws/template2
PROJECT_DIR="${DEPLOY_BASE_DIR}/${PROJECT_NAME}"
DEPLOY_DIR="${DEPLOY_BASE_DIR}/deploy"
CURRENT_DIR="${DEPLOY_BASE_DIR}/deploy/current"

# Get current timestamp for deployment folder
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEPLOY_TARGET="${DEPLOY_DIR}/${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if target directory is writable
check_permissions() {
    local parent_dir=$(dirname "$DEPLOY_BASE_DIR")
    if [[ ! -w "$parent_dir" ]] && [[ ! -w "$DEPLOY_BASE_DIR" ]]; then
        error "Cannot write to deployment directory: $DEPLOY_BASE_DIR"
        error "Please ensure you have write permissions or run with appropriate privileges"
        exit 1
    fi
}

# Create directory structure
create_directories() {
    log "Creating directory structure..."
    
    # Create base directories
    mkdir -p "$DEPLOY_BASE_DIR"
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_TARGET"
    
    success "Directory structure created"
}

# Copy essential files for deployment
copy_files() {
    log "Copying essential files to deployment directory..."
    
    # List of essential files and directories to copy
    ESSENTIAL_FILES=(
        "index.html"
        "404.html"
        "css"
        "js"
        "images"
        "eslint.config.js"
        "package.json"
    )
    
    # Copy files to project directory (only if different from current directory)
    if [[ "$PROJECT_DIR" != "$(pwd)" ]]; then
        for item in "${ESSENTIAL_FILES[@]}"; do
            if [[ -e "$item" ]]; then
                log "Copying $item to project directory..."
                cp -r "$item" "$PROJECT_DIR/"
            else
                warning "File/directory $item not found, skipping..."
            fi
        done
    else
        log "Project directory is same as source, skipping project copy..."
    fi
    
    # Copy files to deployment target
    for item in "${ESSENTIAL_FILES[@]}"; do
        if [[ -e "$item" ]]; then
            log "Copying $item to deployment target..."
            cp -r "$item" "$DEPLOY_TARGET/"
        fi
    done
    
    success "Essential files copied successfully"
}

# Create or update symlink to current deployment
update_symlink() {
    log "Updating symlink to current deployment..."
    
    # Remove existing symlink if it exists
    if [[ -L "$CURRENT_DIR" ]]; then
        rm "$CURRENT_DIR"
    elif [[ -d "$CURRENT_DIR" ]]; then
        warning "Current directory exists but is not a symlink, removing..."
        rm -rf "$CURRENT_DIR"
    fi
    
    # Create new symlink (relative path) inside deploy directory
    cd "$DEPLOY_BASE_DIR/deploy"
    ln -sf "$TIMESTAMP" "current"
    cd - > /dev/null
    
    success "Symlink updated: current -> $TIMESTAMP"
}

# Clean up old deployments, keep only 5 most recent
cleanup_old_deployments() {
    log "Cleaning up old deployments..."
    
    cd "$DEPLOY_DIR"
    
    # Count current deployments
    DEPLOYMENT_COUNT=$(ls -1 | wc -l)
    
    if [[ $DEPLOYMENT_COUNT -gt 5 ]]; then
        # Get directories sorted by modification time (oldest first)
        # Keep only the 5 most recent deployments
        DIRS_TO_DELETE=$(ls -1t | tail -n +6)
        
        if [[ -n "$DIRS_TO_DELETE" ]]; then
            log "Removing old deployments: $(echo $DIRS_TO_DELETE | tr '\n' ' ')"
            echo "$DIRS_TO_DELETE" | xargs rm -rf
            success "Old deployments cleaned up"
        fi
    else
        log "No cleanup needed. Current deployments: $DEPLOYMENT_COUNT"
    fi
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check if symlink exists and points to correct location
    EXPECTED_LINK="$TIMESTAMP"
    if [[ -L "$CURRENT_DIR" ]] && [[ "$(readlink "$CURRENT_DIR")" == "$EXPECTED_LINK" ]]; then
        success "Symlink verification passed"
    else
        error "Symlink verification failed"
        error "Expected: $EXPECTED_LINK"
        error "Actual: $(readlink "$CURRENT_DIR" 2>/dev/null || echo 'N/A')"
        exit 1
    fi
    
    # Check if essential files exist in current deployment
    ESSENTIAL_FILES=("index.html" "404.html" "css" "js" "images")
    
    for item in "${ESSENTIAL_FILES[@]}"; do
        if [[ -e "$CURRENT_DIR/$item" ]]; then
            log "✓ $item exists in current deployment"
        else
            warning "✗ $item missing in current deployment"
        fi
    done
    
    success "Deployment verification completed"
}

# Display deployment info
show_deployment_info() {
    log "Deployment Information:"
    echo "  Project: $PROJECT_NAME"
    echo "  Timestamp: $TIMESTAMP"
    echo "  Project Directory: $PROJECT_DIR"
    echo "  Deploy Directory: $DEPLOY_TARGET"
    echo "  Current Symlink: $CURRENT_DIR -> $(readlink "$CURRENT_DIR" 2>/dev/null || echo 'N/A')"
    echo ""
    echo "  Directory Structure:"
    echo "  jenkins-ws/template2/"
    echo "  ├── $PROJECT_NAME/"
    echo "  │   ├── index.html"
    echo "  │   ├── 404.html"
    echo "  │   ├── css/"
    echo "  │   ├── js/"
    echo "  │   └── images/"
    echo "  ├── deploy/"
    echo "  │   ├── $TIMESTAMP/"
    echo "  │   ├── current -> $TIMESTAMP"
    echo "  │   └── ..."
}

# Main deployment process
main() {
    log "Starting deployment of $PROJECT_NAME..."
    
    # Check permissions
    check_permissions
    
    # Create directories
    create_directories
    
    # Copy files
    copy_files
    
    # Update symlink
    update_symlink
    
    # Cleanup old deployments
    cleanup_old_deployments
    
    # Verify deployment
    verify_deployment
    
    # Show deployment info
    show_deployment_info
    
    success "🚀 Deployment completed successfully!"
    log "You can access the application at: $CURRENT_DIR"
}

# Run main function
main "$@"