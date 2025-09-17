#!/bin/bash

# Remote server deployment script for web-performance-project1-initial
# This script deploys the application to a remote server via SSH

set -e  # Exit on any error

# Configuration from environment variables
SSH_USER="${SSH_USER:-newbie}"
DEPLOY_SERVER="${DEPLOY_SERVER:-118.69.34.46}"
SSH_PORT="${SSH_PORT:-3334}"
WEB_SERVER="${WEB_SERVER:-10.1.1.195}"
SSH_KEY="${SSH_KEY}"
DEPLOY_USER="${DEPLOY_USER:-tannp}"
# PERSONAL_FOLDER removed - using DEPLOY_USER directly
REMOTE_BASE_PATH="${REMOTE_BASE_PATH:-/usr/share/nginx/html/jenkins}"
TIMESTAMP="${TIMESTAMP}"
BUILD_DIR="${BUILD_DIR:-deploy-staging}"
KEEP_DEPLOYMENTS="${KEEP_DEPLOYMENTS:-5}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if required environment variables are set
    if [[ -z "$SSH_KEY" ]]; then
        error "SSH_KEY environment variable is required"
        exit 1
    fi
    
    if [[ -z "$DEPLOY_USER" ]]; then
        error "DEPLOY_USER environment variable is required"
        exit 1
    fi
    
    if [[ -z "$TIMESTAMP" ]]; then
        error "TIMESTAMP environment variable is required"
        exit 1
    fi
    
    # Check if SSH key file exists
    if [[ ! -f "$SSH_KEY" ]]; then
        error "SSH key file not found: $SSH_KEY"
        exit 1
    fi
    
    # Check if build directory exists
    if [[ ! -d "$BUILD_DIR" ]]; then
        error "Build directory not found: $BUILD_DIR"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Test SSH connection
test_ssh_connection() {
    log "Testing SSH connection..."
    
    if ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER@$DEPLOY_SERVER" "echo 'SSH connection successful'" >/dev/null 2>&1; then                                            
        success "SSH connection test passed"
    else
        error "SSH connection failed to $SSH_USER@$DEPLOY_SERVER:$SSH_PORT"
        error "Please check your SSH credentials and network connectivity"
        exit 1
    fi
}

# Create remote directory structure
create_remote_directories() {
    log "Creating remote directory structure..."
    
    ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$DEPLOY_SERVER" "
        # Create deployment directories
        mkdir -p $REMOTE_BASE_PATH/$DEPLOY_USER/web-performance-project1-initial
        mkdir -p $REMOTE_BASE_PATH/$DEPLOY_USER/deploy/$TIMESTAMP
        
        # Set proper permissions
        chmod 755 $REMOTE_BASE_PATH/$DEPLOY_USER
        chmod 755 $REMOTE_BASE_PATH/$DEPLOY_USER/web-performance-project1-initial
        chmod 755 $REMOTE_BASE_PATH/$DEPLOY_USER/deploy
        chmod 755 $REMOTE_BASE_PATH/$DEPLOY_USER/deploy/$TIMESTAMP
        
        echo 'Remote directories created successfully'
    "
    
    success "Remote directories created"
}

# Prepare build directory for remote deployment
prepare_build_for_remote() {
    log "Preparing build directory for remote deployment..."
    
    # List of essential files and directories to verify/copy
    ESSENTIAL_FILES=(
        "index.html"
        "404.html"
        "css"
        "js"
        "images"
        "eslint.config.js"
        "package.json"
    )
    
    # Verify all essential files exist in BUILD_DIR
    for item in "${ESSENTIAL_FILES[@]}"; do
        if [[ -e "$BUILD_DIR/$item" ]]; then
            log "✓ Found $item in build directory"
        else
            warning "File/directory $item not found in build directory"
        fi
    done
    
    success "Build directory verification completed"
}

# Upload deployment files
upload_files() {
    log "Uploading deployment files..."
    
    # Upload to timestamped directory
    log "Uploading to timestamped directory: deploy/$TIMESTAMP/"
    scp -i "$SSH_KEY" -P "$SSH_PORT" -o StrictHostKeyChecking=no -r "$BUILD_DIR"/* "$SSH_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$DEPLOY_USER/deploy/$TIMESTAMP/"                                                         
    
    # Upload to main project directory
    log "Uploading to main project directory: web-performance-project1-initial/"
    scp -i "$SSH_KEY" -P "$SSH_PORT" -o StrictHostKeyChecking=no -r "$BUILD_DIR"/* "$SSH_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$DEPLOY_USER/web-performance-project1-initial/"                                          
    
    success "Files uploaded successfully"
}

# Update symlinks and cleanup old deployments
update_symlinks_and_cleanup() {
    log "Updating symlinks and cleaning up old deployments..."
    
    # Calculate keep number locally
    local KEEP_NUM=$((KEEP_DEPLOYMENTS + 1))
    
    ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$DEPLOY_SERVER" \
        "cd $REMOTE_BASE_PATH/$DEPLOY_USER && \
         echo 'Updating current symlink...' && \
         cd deploy && \
         rm -f current && \
         ln -sf $TIMESTAMP current && \
         if [[ -L current && -d current ]]; then \
             echo 'Current symlink updated successfully'; \
         else \
             echo 'Warning: Current symlink may not be working properly'; \
         fi && \
         echo 'Cleaning up old deployments (keeping last $KEEP_DEPLOYMENTS)...' && \
         cd deploy && \
         ls -1t | grep -E '^[0-9]{14}$' | tail -n +$KEEP_NUM | xargs -r rm -rf && \
         echo 'Remaining deployments:' && \
         ls -la | grep -E '^d.*[0-9]{14}$' || echo 'No dated directories found'"
    
    success "Symlinks updated and cleanup completed"
}

# Get deployment information
get_deployment_info() {
    log "Getting deployment information..."
    
    local deployment_url="http://$WEB_SERVER/jenkins/$DEPLOY_USER/deploy/current/"
    local project_url="http://$WEB_SERVER/jenkins/$DEPLOY_USER/web-performance-project1-initial/"
    
    echo ""
    echo "🚀 Remote deployment completed successfully!"
    echo ""
    echo "📱 Your application is now live at:"
    echo "   Current URL: $deployment_url"
    echo "   Project URL: $project_url"
    echo ""
    echo "🔧 Deployment Information:"
    echo "   Server: $SSH_USER@$DEPLOY_SERVER:$SSH_PORT"
    echo "   Deploy Path: $REMOTE_BASE_PATH/$DEPLOY_USER/"
    echo "   Timestamp: $TIMESTAMP"
    echo "   Deploy User: $DEPLOY_USER"
    echo ""
}

# Show usage information
show_usage() {
    echo "Usage: $0"
    echo ""
    echo "Environment Variables Required:"
    echo "  SSH_USER              SSH username (default: newbie)"
    echo "  DEPLOY_SERVER         SSH server IP/hostname (default: 118.69.34.46)"
    echo "  SSH_PORT             SSH port (default: 3334)"
    echo "  WEB_SERVER           Web server IP/hostname (default: 10.1.1.195)"
    echo "  SSH_KEY              Path to SSH private key file"
    echo "  DEPLOY_USER          Directory name for deployment (default: lanlee)"
    echo "  DEPLOY_USER          Directory name for deployment (e.g., lanlh)"
    echo "  REMOTE_BASE_PATH     Base deployment path (default: /usr/share/nginx/html/jenkins)"
    echo "  TIMESTAMP            Deployment timestamp (YYYYMMDDHHMMSS format)"
    echo "  KEEP_DEPLOYMENTS     Number of deployments to keep (default: 5)"
    echo "  BUILD_DIR            Build directory (default: deploy-staging)"
    echo ""
    echo "Examples:"
    echo "  # Set environment variables and run"
    echo "  export SSH_KEY=/path/to/private/key"
    echo "  export DEPLOY_USER=lanlh"
    echo "  export TIMESTAMP=20240915143022"
    echo "  export KEEP_DEPLOYMENTS=10"
    echo "  $0"
}

# Main deployment process
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log "Starting remote deployment..."
    
    # Run deployment steps
    check_prerequisites
    test_ssh_connection
    prepare_build_for_remote
    create_remote_directories
    upload_files
    update_symlinks_and_cleanup
    get_deployment_info
    
    success "🎉 Remote deployment completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"