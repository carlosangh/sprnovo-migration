#!/bin/bash
# Production Frontend Build Script for SPR System
# Enhanced version with error handling and validation

set -e  # Exit on any error

# Configuration
FRONTEND_DIR="${FRONTEND_DIR:-/opt/spr/frontend}"
NODE_ENV="${NODE_ENV:-production}"
BUILD_OUTPUT="${BUILD_OUTPUT:-build}"
BACKUP_BUILDS="${BACKUP_BUILDS:-true}"

echo "=== SPR Frontend Build Process Started ==="
echo "Environment: $NODE_ENV"
echo "Frontend Directory: $FRONTEND_DIR"
echo "Build Output: $BUILD_OUTPUT"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to create backup of previous build
backup_previous_build() {
    if [ "$BACKUP_BUILDS" = "true" ] && [ -d "$FRONTEND_DIR/$BUILD_OUTPUT" ]; then
        local backup_dir="$FRONTEND_DIR/build_backups/$(date +%Y%m%d_%H%M%S)"
        log "Creating backup of previous build at: $backup_dir"
        mkdir -p "$FRONTEND_DIR/build_backups"
        mv "$FRONTEND_DIR/$BUILD_OUTPUT" "$backup_dir"
        
        # Keep only last 5 backups
        cd "$FRONTEND_DIR/build_backups"
        ls -t | tail -n +6 | xargs -r rm -rf
        cd "$FRONTEND_DIR"
    fi
}

# Validate prerequisites
validate_environment() {
    log "Validating build environment..."
    
    # Check if frontend directory exists
    if [ ! -d "$FRONTEND_DIR" ]; then
        log "ERROR: Frontend directory $FRONTEND_DIR not found"
        exit 1
    fi
    
    cd "$FRONTEND_DIR"
    log "Current directory: $(pwd)"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        log "ERROR: package.json not found in $FRONTEND_DIR"
        exit 1
    fi
    
    # Check Node.js version
    if command -v node > /dev/null; then
        local node_version=$(node --version)
        log "Node.js version: $node_version"
    else
        log "ERROR: Node.js not found"
        exit 1
    fi
    
    # Check npm version
    if command -v npm > /dev/null; then
        local npm_version=$(npm --version)
        log "npm version: $npm_version"
    else
        log "ERROR: npm not found"
        exit 1
    fi
}

# Install or update dependencies
install_dependencies() {
    log "Checking dependencies..."
    
    # Check if package-lock.json exists and is newer than node_modules
    if [ -f "package-lock.json" ] && [ ! -d "node_modules" -o "package-lock.json" -nt "node_modules" ]; then
        log "Installing/updating dependencies..."
        npm ci --legacy-peer-deps --production=false
    elif [ ! -d "node_modules" ]; then
        log "Installing dependencies (no package-lock.json found)..."
        npm install --legacy-peer-deps
    else
        log "Dependencies are up to date"
    fi
    
    # Verify critical dependencies
    if [ ! -d "node_modules/react" ]; then
        log "ERROR: React not found in node_modules"
        exit 1
    fi
}

# Build the frontend
build_frontend() {
    log "Starting frontend build process..."
    
    # Set environment variables for build
    export NODE_ENV="$NODE_ENV"
    export GENERATE_SOURCEMAP=false  # Disable sourcemaps for production
    export INLINE_RUNTIME_CHUNK=false
    
    # Run the build
    npm run build
    
    if [ $? -ne 0 ]; then
        log "ERROR: Frontend build failed"
        exit 1
    fi
    
    log "Frontend build completed successfully"
}

# Validate build output
validate_build() {
    log "Validating build output..."
    
    if [ ! -d "$BUILD_OUTPUT" ]; then
        log "ERROR: Build directory $BUILD_OUTPUT was not created"
        exit 1
    fi
    
    # Check for index.html
    if [ ! -f "$BUILD_OUTPUT/index.html" ]; then
        log "ERROR: index.html not found in build output"
        exit 1
    fi
    
    # Check for static directory
    if [ ! -d "$BUILD_OUTPUT/static" ]; then
        log "WARNING: static directory not found in build output"
    fi
    
    # Calculate build size
    local build_size=$(du -sh "$BUILD_OUTPUT" | cut -f1)
    log "Build size: $build_size"
    
    # List build contents
    log "Build contents:"
    ls -la "$BUILD_OUTPUT/"
    
    # Check for large files (warning if any file > 2MB)
    local large_files=$(find "$BUILD_OUTPUT" -type f -size +2M)
    if [ -n "$large_files" ]; then
        log "WARNING: Large files found in build (>2MB):"
        echo "$large_files" | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            log "  $file ($size)"
        done
    fi
}

# Set proper permissions
set_permissions() {
    log "Setting proper permissions for build files..."
    
    # Set ownership if running as root
    if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$BUILD_OUTPUT"
    fi
    
    # Set appropriate permissions
    find "$BUILD_OUTPUT" -type f -exec chmod 644 {} \;
    find "$BUILD_OUTPUT" -type d -exec chmod 755 {} \;
}

# Main execution flow
main() {
    validate_environment
    backup_previous_build
    install_dependencies
    build_frontend
    validate_build
    set_permissions
    
    log "=== Frontend Build Process Completed Successfully ==="
    log "Build location: $FRONTEND_DIR/$BUILD_OUTPUT"
    log "Ready for deployment to web server"
    
    # Optional: Check nginx status
    if command -v systemctl > /dev/null && systemctl is-active --quiet nginx; then
        log "Nginx service is running and ready to serve the build"
    elif command -v service > /dev/null && service nginx status > /dev/null 2>&1; then
        log "Nginx service is running and ready to serve the build"
    else
        log "WARNING: Nginx service status could not be determined"
    fi
}

# Execute main function
main "$@"