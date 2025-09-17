#!/bin/bash

# Firebase Deployment Script - Tannp's Custom Version
# Script này deploy ứng dụng lên Firebase Hosting
# Author: tannp
# Created: $(date +%Y-%m-%d)

set -e  # Thoát ngay khi có lỗi

# Cấu hình dự án
PROJECT_NAME="web-performance-project1-initial"
FIREBASE_PROJECT_ID="jenkins-ws2-b6b91"  # Firebase project ID
BUILD_DIR="dist"  # Thư mục chứa files để deploy
FIREBASE_TOKEN="${FIREBASE_TOKEN:-}"  # Firebase authentication token

# Màu sắc cho output đẹp mắt
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Các hàm logging
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} 📋 $1"
}

error() {
    echo -e "${RED}[LỖI]${NC} ❌ $1" >&2
}

success() {
    echo -e "${GREEN}[THÀNH CÔNG]${NC} ✅ $1"
}

warning() {
    echo -e "${YELLOW}[CẢNH BÁO]${NC} ⚠️ $1"
}

info() {
    echo -e "${PURPLE}[INFO]${NC} ℹ️ $1"
}

# Thiết lập xác thực Firebase
setup_credentials() {
    log "Đang thiết lập xác thực Firebase..."
    
    if [[ -z "$FIREBASE_TOKEN" ]]; then
        error "Không tìm thấy Firebase token!"
        error "Vui lòng set biến FIREBASE_TOKEN"
        info "Lấy token bằng lệnh: firebase login:ci"
        exit 1
    fi
    
    info "Sử dụng Firebase token để xác thực"
    success "Firebase token đã được cấu hình"
}

# Kiểm tra các yêu cầu cần thiết
check_prerequisites() {
    log "Kiểm tra các yêu cầu cần thiết..."
    
    # Kiểm tra Firebase CLI đã được cài đặt chưa
    if ! command -v firebase &> /dev/null; then
        error "Firebase CLI chưa được cài đặt"
        info "Cài đặt với lệnh: npm install -g firebase-tools"
        exit 1
    fi
    
    info "Firebase CLI version: $(firebase --version)"
    success "Kiểm tra yêu cầu hoàn tất"
}

# Chuẩn bị thư mục build
prepare_build() {
    log "Chuẩn bị thư mục build..."

    # Xóa thư mục build cũ nếu có
    if [[ -d "$BUILD_DIR" ]]; then
        warning "Xóa thư mục build cũ: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi

    # Tạo thư mục build mới
    mkdir -p "$BUILD_DIR"
    info "Đã tạo thư mục: $BUILD_DIR"

    # Copy các file cần thiết để deploy
    ESSENTIAL_FILES=(
        "index.html"
        "404.html"
        "css"
        "js"
        "images"
        "eslint.config.js"
        "package.json"
    )

    log "Đang copy các file cần thiết..."
    for item in "${ESSENTIAL_FILES[@]}"; do
        if [[ -e "$item" ]]; then
            info "✓ Copy $item vào build directory"
            cp -r "$item" "$BUILD_DIR/"
        else
            warning "Không tìm thấy $item, bỏ qua..."
        fi
    done

    success "Thư mục build đã sẵn sàng"
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
    info "Deploying từ thư mục: $BUILD_DIR"
    info "Firebase Project: $FIREBASE_PROJECT_ID"
    NODE_OPTIONS="--max-old-space-size=4096" firebase deploy --only hosting --project="$FIREBASE_PROJECT_ID" --token="$FIREBASE_TOKEN" --non-interactive

    success "Deployment to Firebase completed"
}

# Get deployment URL
get_deployment_url() {
    log "Getting deployment information..."

    local hosting_url="https://${FIREBASE_PROJECT_ID}.web.app"
    local custom_domain_url="https://${FIREBASE_PROJECT_ID}.firebaseapp.com"

    echo ""
    echo "🚀 Deployment hoàn thành thành công!"
    echo ""
    echo "📱 Ứng dụng của bạn đã live tại:"
    echo "   URL chính: $hosting_url"
    echo "   URL phụ: $custom_domain_url"
    echo ""
    echo "🔧 Thông tin dự án:"
    echo "   Project ID: $FIREBASE_PROJECT_ID"
    echo "   Thư mục build: $BUILD_DIR"
    echo "   Thời gian deploy: $(date '+%d/%m/%Y %H:%M:%S')"
    echo "   Deployed by: tannp 🎯"
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

    log "Bắt đầu Firebase deployment cho $PROJECT_NAME..."
    info "Tác giả: tannp | $(date '+%d/%m/%Y %H:%M:%S')"

    # Chạy các bước deployment
    check_prerequisites
    setup_credentials
    prepare_build
    deploy_to_firebase
    get_deployment_url

    # Dọn dẹp
    if [[ "$keep_build" == true ]]; then
        cleanup --keep-build
    else
        cleanup
    fi

    success "🎉 Firebase deployment hoàn thành! Chúc mừng! 🎊"
}

# Handle script interruption
trap 'error "Deployment interrupted"; cleanup; exit 1' INT TERM

# Run main function with all arguments
main "$@"