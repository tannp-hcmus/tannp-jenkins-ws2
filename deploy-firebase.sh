#!/bin/bash

# Firebase deployment script for web-performance-project1-initial
# This script deploys the application to Firebase Hosting

set -e  # Exit on any error

# Configuration
PROJECT_NAME="web-performance-project1-initial"
FIREBASE_PROJECT_ID="tannp-jenkins-ws2"  # From your Firebase config
BUILD_DIR="dist"  # Directory to deploy
FIREBASE_TOKEN="${FIREBASE_TOKEN:-}"

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

# Setup Firebase token authentication
setup_credentials() {
    log "Setting up Firebase authentication..."
    
    if [[ -z "$FIREBASE_TOKEN" ]]; then
        error "No Firebase token found!"
        error "Please set FIREBASE_TOKEN environment variable"
        error "Get your token by running: firebase login:ci"
        exit 1
    fi
    
    log "Using Firebase token for authentication"
    success "Firebase token configured"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if firebase CLI is installed
    if ! command -v firebase &> /dev/null; then
        error "Firebase CLI is not installed"
        error "Install it with: npm install -g firebase-tools"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Prepare build directory
prepare_build() {
    log "Preparing build directory..."

    # Remove existing build directory
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi

    # Create build directory
    mkdir -p "$BUILD_DIR"

    # Copy essential files for deployment
    ESSENTIAL_FILES=(
        "index.html"
        "404.html"
        "css"
        "js"
        "images"
        "eslint.config.js"
        "package.json"
    )

    for item in "${ESSENTIAL_FILES[@]}"; do
        if [[ -e "$item" ]]; then
            log "Copying $item to build directory..."
            cp -r "$item" "$BUILD_DIR/"
        else
            warning "File/directory $item not found, skipping..."
        fi
    done

    success "Build directory prepared"
}


# Deploy to Firebase
deploy_to_firebase() {
    log "Deploying to Firebase Hosting..."

    # Verify Firebase configuration
    log "Verifying Firebase configuration..."
    if [[ ! -f "firebase.json" ]]; then
        error "firebase.json not found"
        error "Run 'firebase init' to initialize Firebase configuration"
        exit 1
    fi

    # Verify authentication using Firebase token
    log "Verifying Firebase authentication..."
    log "Using Firebase token authentication"

    # Test Firebase authentication with projects list
    if ! firebase projects:list --token="$FIREBASE_TOKEN" >/dev/null 2>&1; then
        error "Firebase authentication failed"
        error "Invalid or expired Firebase token"
        error "Project ID: $FIREBASE_PROJECT_ID"
        error "Generate a new token with: firebase login:ci"
        exit 1
    fi

    log "Firebase authentication successful"

    # Deploy to Firebase using token
    log "Starting Firebase deployment..."
    NODE_OPTIONS="--max-old-space-size=4096" firebase deploy --only hosting --project="$FIREBASE_PROJECT_ID" --token="$FIREBASE_TOKEN" --non-interactive

    success "Deployment to Firebase completed"
}

# Get deployment URL
get_deployment_url() {
    log "Getting deployment information..."

    local hosting_url="https://${FIREBASE_PROJECT_ID}.web.app"
    local custom_domain_url="https://${FIREBASE_PROJECT_ID}.firebaseapp.com"

    echo ""
    echo "🚀 Deployment completed successfully!"
    echo ""
    echo "📱 Your application is now live at:"
    echo "   Primary URL: $hosting_url"
    echo "   Alternative: $custom_domain_url"
    echo ""
    echo "🔧 Project Information:"
    echo "   Project ID: $FIREBASE_PROJECT_ID"
    echo "   Build Directory: $BUILD_DIR"
    echo "   Deployment Time: $(date)"
}

# Cleanup build directory
cleanup() {
    # Clean up build directory
    if [[ "$1" == "--keep-build" ]]; then
        log "Keeping build directory as requested"
    else
        log "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
        success "Cleanup completed"
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --keep-build    Keep the build directory after deployment"
    echo "  --help         Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  FIREBASE_TOKEN      Firebase authentication token (required)"
    echo ""
    echo "Examples:"
    echo "  # Get Firebase token:"
    echo "  firebase login:ci"
    echo ""
    echo "  # Use token for deployment:"
    echo "  export FIREBASE_TOKEN='your-firebase-token-here'"
    echo "  $0"
}

# Main deployment process
main() {
    local keep_build=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-build)
                keep_build=true
                shift
                ;;
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

    log "Starting Firebase deployment of $PROJECT_NAME..."

    # Run deployment steps
    check_prerequisites
    setup_credentials
    prepare_build
    deploy_to_firebase
    get_deployment_url

    # Cleanup
    if [[ "$keep_build" == true ]]; then
        cleanup --keep-build
    else
        cleanup
    fi

    success "🎉 Firebase deployment completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted"; cleanup; exit 1' INT TERM

# Run main function with all arguments
main "$@"