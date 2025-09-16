#!/bin/bash

# Enhanced deployment script for web-performance-project1-initial
# Supports both Firebase and Remote Server deployment

set -e  # Exit on any error

# Configuration variables
FIREBASE_PROJECT="${FIREBASE_PROJECT:-your-firebase-project-id}"
REMOTE_USER="${REMOTE_USER:-newbie}"
REMOTE_HOST="${REMOTE_HOST:-118.69.34.46}"
REMOTE_PORT="${REMOTE_PORT:-3334}"
REMOTE_PATH="${REMOTE_PATH:-/usr/share/nginx/html/jenkins}"
PROJECT_NAME="${PROJECT_NAME:-web-performance-project1-initial}"
DEPLOY_FILES="${DEPLOY_FILES:-index.html 404.html css js images}"
DEPLOY_USER="${DEPLOY_USER:-$(whoami)}"
DEPLOY_DATE=$(date +%Y%m%d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy web-performance-project1-initial to Firebase and/or Remote Server

OPTIONS:
    -f, --firebase-only     Deploy only to Firebase
    -r, --remote-only      Deploy only to Remote Server
    -h, --help             Show this help message
    --firebase-project     Firebase project ID (default: $FIREBASE_PROJECT)
    --remote-host          Remote server host (default: $REMOTE_HOST)
    --remote-user          Remote server user (default: $REMOTE_USER)
    --remote-port          Remote server port (default: $REMOTE_PORT)
    --deploy-user          Deployment user name (default: $DEPLOY_USER)

EXAMPLES:
    $0                     Deploy to both Firebase and Remote Server
    $0 --firebase-only     Deploy only to Firebase
    $0 --remote-only       Deploy only to Remote Server
    $0 --firebase-project my-project --deploy-user john

ENVIRONMENT VARIABLES:
    FIREBASE_TOKEN         Firebase CI token (required for Firebase deployment)
    SSH_KEY               Path to SSH private key for remote deployment
    
EOF
}

# Parse command line arguments
DEPLOY_FIREBASE=true
DEPLOY_REMOTE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--firebase-only)
            DEPLOY_FIREBASE=true
            DEPLOY_REMOTE=false
            shift
            ;;
        -r|--remote-only)
            DEPLOY_FIREBASE=false
            DEPLOY_REMOTE=true
            shift
            ;;
        --firebase-project)
            FIREBASE_PROJECT="$2"
            shift 2
            ;;
        --remote-host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --remote-user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --remote-port)
            REMOTE_PORT="$2"
            shift 2
            ;;
        --deploy-user)
            DEPLOY_USER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate project directory
if [ ! -d "$PROJECT_NAME" ]; then
    log_error "Project directory '$PROJECT_NAME' not found!"
    exit 1
fi

log_info "Starting deployment process..."
log_info "Deploy Date: $DEPLOY_DATE"
log_info "Deploy User: $DEPLOY_USER"
log_info "Project: $PROJECT_NAME"

# Deploy to Firebase
deploy_firebase() {
    log_info "Deploying to Firebase Hosting..."
    
    if [ -z "$FIREBASE_TOKEN" ]; then
        log_error "FIREBASE_TOKEN environment variable is not set!"
        return 1
    fi
    
    cd "$PROJECT_NAME"
    
    # Check if firebase.json exists
    if [ ! -f "firebase.json" ]; then
        log_error "firebase.json not found in project directory!"
        cd ..
        return 1
    fi
    
    # Deploy to Firebase
    if firebase deploy --token "$FIREBASE_TOKEN" --only hosting --project="$FIREBASE_PROJECT"; then
        log_success "Firebase deployment completed successfully!"
    else
        log_error "Firebase deployment failed!"
        cd ..
        return 1
    fi
    
    cd ..
}

# Deploy to Remote Server
deploy_remote() {
    log_info "Deploying to Remote Server..."
    
    if [ -z "$SSH_KEY" ]; then
        log_error "SSH_KEY environment variable is not set!"
        return 1
    fi
    
    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH key file '$SSH_KEY' not found!"
        return 1
    fi
    
    # Test SSH connection
    log_info "Testing SSH connection to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT..."
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH connection successful'"; then
        log_error "Failed to connect to remote server!"
        return 1
    fi
    
    # Create directory structure on remote server
    log_info "Creating directory structure on remote server..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "
        mkdir -p $REMOTE_PATH/${DEPLOY_USER}2/$PROJECT_NAME
        mkdir -p $REMOTE_PATH/${DEPLOY_USER}2/deploy/$DEPLOY_DATE
    "
    
    # Copy files to remote server
    log_info "Copying files to remote server..."
    cd "$PROJECT_NAME"
    
    for file in $DEPLOY_FILES; do
        if [ -e "$file" ]; then
            log_info "Copying $file..."
            # Copy to main project directory
            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" -P "$REMOTE_PORT" -r "$file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/${DEPLOY_USER}2/$PROJECT_NAME/"
            # Copy to dated deployment directory
            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" -P "$REMOTE_PORT" -r "$file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/${DEPLOY_USER}2/deploy/$DEPLOY_DATE/"
        else
            log_warning "File/directory '$file' not found, skipping..."
        fi
    done
    
    # Create symlink and cleanup old deployments
    log_info "Creating symlink and cleaning up old deployments..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "
        cd $REMOTE_PATH/${DEPLOY_USER}2/deploy
        rm -f current
        ln -sf $DEPLOY_DATE current
        
        # Keep only 5 most recent deployments
        ls -t | grep -E '^[0-9]{8}$' | tail -n +6 | xargs -r rm -rf
        
        echo 'Current deployments:'
        ls -la | grep -E '^[0-9]{8}|current'
    "
    
    cd ..
    log_success "Remote server deployment completed successfully!"
}

# Main deployment logic
DEPLOYMENT_SUCCESS=true

if [ "$DEPLOY_FIREBASE" = true ]; then
    if deploy_firebase; then
        log_success "Firebase deployment successful"
    else
        log_error "Firebase deployment failed"
        DEPLOYMENT_SUCCESS=false
    fi
fi

if [ "$DEPLOY_REMOTE" = true ]; then
    if deploy_remote; then
        log_success "Remote server deployment successful"
    else
        log_error "Remote server deployment failed"
        DEPLOYMENT_SUCCESS=false
    fi
fi

# Final status
if [ "$DEPLOYMENT_SUCCESS" = true ]; then
    log_success "All deployments completed successfully! 🚀"
    echo
    log_info "Deployment Summary:"
    log_info "  Date: $DEPLOY_DATE"
    log_info "  User: $DEPLOY_USER"
    if [ "$DEPLOY_FIREBASE" = true ]; then
        log_info "  Firebase: ✅ Deployed to project '$FIREBASE_PROJECT'"
    fi
    if [ "$DEPLOY_REMOTE" = true ]; then
        log_info "  Remote: ✅ Deployed to $REMOTE_HOST:$REMOTE_PATH/${DEPLOY_USER}2/"
    fi
    exit 0
else
    log_error "Some deployments failed! ❌"
    exit 1
fi