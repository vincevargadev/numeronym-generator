#!/bin/bash

# Release script for numeronym-generator.vincevarga.dev
#
# This script handles the complete deployment of the Numeronym Generator WASM app.
# It is designed to be self-contained and can bootstrap a fresh server if needed.
#
# Server requirements:
#   - Caddy installed and running as a systemd service
#   - SSH access with the configured key
#
# Local requirements:
#   - Rust toolchain (rustup)
#   - wasm-pack (cargo install wasm-pack)
#
# Server structure (created automatically if missing):
#   /etc/caddy/Caddyfile              - Main config: imports all snippets from conf.d
#   /etc/caddy/conf.d/*.caddy         - Individual site configurations
#   /var/www/{domain}/                - Web root for each site
#
# Usage:
#   ./release.sh           - Normal release
#   ./release.sh --debug   - Release with additional health checks
#   ./release.sh --help    - Show help

# Stop execution on any failure
set -eo pipefail

# Parse command line arguments
DEBUG_MODE=false
for arg in "$@"; do
    case $arg in
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--debug] [--help]"
            echo ""
            echo "Options:"
            echo "  --debug    Enable debug mode with additional health checks"
            echo "  --help     Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

#==============================================================================
# CONFIGURATION
#==============================================================================

# SSH configuration
SSH_KEY="~/.ssh/id_ed25519_scaleway"
SSH_HOST="root@51.15.107.139"
SSH_PATH="ssh -i $SSH_KEY $SSH_HOST"

# Project configuration
# The domain is used for both the Caddy snippet filename and the web root directory
DOMAIN="numeronym-generator.vincevarga.dev"
CADDY_SNIPPET="${DOMAIN}.caddy"

# Server paths
SERVER_WEB_ROOT="/var/www/$DOMAIN"
CADDY_CONF_DIR="/etc/caddy/conf.d"
CADDY_MAIN_CONFIG="/etc/caddy/Caddyfile"

#==============================================================================
# RELEASE PROCESS
#==============================================================================

# Generate timestamp for backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="${SERVER_WEB_ROOT}.${TIMESTAMP}.bak"

# Start timing the release process
START_TIME=$(date +%s)

echo "Starting release process for $DOMAIN..."

# Build WebAssembly package
echo "🟡 Building WebAssembly package..."
wasm-pack build --target web
echo "🟢 WebAssembly package built."

# Debug mode health checks
if [ "$DEBUG_MODE" = true ]; then
    # Verify Caddy is installed on server
    echo "🟡 Verifying Caddy installation on server..."
    $SSH_PATH "caddy --version"
    echo "🟢 Caddy installation verified."

    # Check current Caddy status
    echo "🟡 Checking current Caddy status..."
    $SSH_PATH "sudo systemctl status caddy --no-pager"
    echo "🟢 Current Caddy status checked."
fi

#==============================================================================
# SERVER SETUP (Bootstrap if needed)
#==============================================================================
# This section ensures the server has the correct Caddy configuration structure.
# It's safe to run on every deploy - it only creates what's missing.

echo "🟡 Ensuring server Caddy configuration structure..."
$SSH_PATH "
# Create conf.d directory if it doesn't exist
if [ ! -d '$CADDY_CONF_DIR' ]; then
    echo 'Creating $CADDY_CONF_DIR directory...'
    sudo mkdir -p '$CADDY_CONF_DIR'
fi

# Create or fix main Caddyfile if it doesn't import from conf.d
if [ ! -f '$CADDY_MAIN_CONFIG' ] || ! grep -q 'import.*conf.d' '$CADDY_MAIN_CONFIG'; then
    echo 'Setting up main Caddyfile to import from conf.d...'
    echo 'import $CADDY_CONF_DIR/*.caddy' | sudo tee '$CADDY_MAIN_CONFIG' > /dev/null
    echo 'Main Caddyfile configured.'
else
    echo 'Main Caddyfile already configured correctly.'
fi
"
echo "🟢 Server Caddy configuration structure verified."

#==============================================================================
# DEPLOYMENT
#==============================================================================

# Backup existing deployment
echo "🟡 Backing up existing deployment..."
$SSH_PATH "if [ -d '$SERVER_WEB_ROOT' ]; then sudo mv '$SERVER_WEB_ROOT' '$BACKUP_PATH' && echo 'Backup created at $BACKUP_PATH'; else echo 'No existing deployment to backup'; fi"
echo "🟢 Existing deployment backed up."

# Copy Caddy snippet to server conf.d
echo "🟡 Copying Caddy snippet to server..."
if [ "$DEBUG_MODE" = true ]; then
    scp -i $SSH_KEY $CADDY_SNIPPET $SSH_HOST:$CADDY_CONF_DIR/$CADDY_SNIPPET
else
    scp -q -i $SSH_KEY $CADDY_SNIPPET $SSH_HOST:$CADDY_CONF_DIR/$CADDY_SNIPPET
fi
echo "🟢 Caddy snippet copied to $CADDY_CONF_DIR/$CADDY_SNIPPET"

# Validate Caddyfile on server (debug mode only)
if [ "$DEBUG_MODE" = true ]; then
    echo "🟡 Validating Caddyfile on server..."
    $SSH_PATH "caddy validate --config $CADDY_MAIN_CONFIG"
    echo "🟢 Caddyfile validation passed."
fi

# Create web root directory on server
echo "🟡 Creating web root directory..."
$SSH_PATH "sudo mkdir -p $SERVER_WEB_ROOT"
echo "🟢 Web root directory created."

# Copy static files to server
echo "🟡 Copying static files to server..."
# List of files to deploy (static site files)
FILES_TO_DEPLOY=(
    "index.html"
    "style.css"
    "script.js"
    "favicon.ico"
    "favicon-16x16.png"
    "favicon-32x32.png"
    "apple-touch-icon.png"
    "android-chrome-192x192.png"
    "android-chrome-512x512.png"
    "site.webmanifest"
    "preview.png"
)

for file in "${FILES_TO_DEPLOY[@]}"; do
    if [ -f "$file" ]; then
        if [ "$DEBUG_MODE" = true ]; then
            scp -i $SSH_KEY "$file" $SSH_HOST:$SERVER_WEB_ROOT/
        else
            scp -q -i $SSH_KEY "$file" $SSH_HOST:$SERVER_WEB_ROOT/
        fi
    fi
done
echo "🟢 Static files copied."

# Copy pkg directory (WebAssembly files)
echo "🟡 Copying WebAssembly package to server..."
$SSH_PATH "mkdir -p $SERVER_WEB_ROOT/pkg"
if [ "$DEBUG_MODE" = true ]; then
    scp -i $SSH_KEY -r pkg/* $SSH_HOST:$SERVER_WEB_ROOT/pkg/
else
    scp -q -i $SSH_KEY -r pkg/* $SSH_HOST:$SERVER_WEB_ROOT/pkg/
fi
echo "🟢 WebAssembly package copied."

# Reload Caddy service
echo "🟡 Reloading Caddy service..."
$SSH_PATH "sudo systemctl reload caddy"
echo "🟢 Caddy service reloaded."

# Check Caddy status after reload (debug mode only)
if [ "$DEBUG_MODE" = true ]; then
    echo "🟡 Checking Caddy status after reload..."
    $SSH_PATH "sudo systemctl status caddy --no-pager"
    echo "🟢 Caddy status checked after reload."
fi

#==============================================================================
# CLEANUP
#==============================================================================

# Clean up old backups (keep only latest 5)
echo "🟡 Cleaning up old backups..."
$SSH_PATH "
cd /var/www && 
BACKUP_COUNT=\$(ls -1d ${DOMAIN}.*.bak 2>/dev/null | wc -l)
if [ \$BACKUP_COUNT -gt 5 ]; then
    echo \"Found \$BACKUP_COUNT backups, cleaning up...\"
    OLD_BACKUPS=\$(ls -1d ${DOMAIN}.*.bak | sort -r | tail -n +6)
    if [ -n \"\$OLD_BACKUPS\" ]; then
        echo 'Removing old backups:'
        echo \"\$OLD_BACKUPS\"
        echo \"\$OLD_BACKUPS\" | xargs -r sudo rm -rf
        echo 'Old backups removed, kept latest 5'
    fi
else
    echo \"No cleanup needed (\$BACKUP_COUNT backups found, keeping up to 5)\"
fi
"
echo "🟢 Old backups cleaned up."

#==============================================================================
# SUMMARY
#==============================================================================

# Calculate and display total execution time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "🎉 Release completed successfully!"
echo ""
if [ $MINUTES -gt 0 ]; then
    echo "⏱️  Total release time: ${MINUTES}m ${SECONDS}s"
else
    echo "⏱️  Total release time: ${SECONDS}s"
fi
echo ""
echo "Your site is now live at https://$DOMAIN"
echo ""
echo "To open the live website in your browser, run:"
echo "🔗 open https://$DOMAIN"
echo ""

say "Release completed successfully!"
