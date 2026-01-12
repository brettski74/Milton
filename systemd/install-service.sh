#!/bin/bash

# Script to help install systemd service files for Milton web server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_TYPE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install systemd service file for Milton web server.

OPTIONS:
    --user          Install as user service (default for non-root users)
    --system        Install as system service (requires sudo)
    --help          Show this help message

EXAMPLES:
    # Install as user service (recommended)
    $0 --user

    # Install as system service (requires sudo)
    sudo $0 --system

EOF
    exit 1
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    # Default to user service if not root, system if root
    if [ "$EUID" -eq 0 ]; then
        SERVICE_TYPE="system"
    else
        SERVICE_TYPE="user"
    fi
else
    while [ $# -gt 0 ]; do
        case "$1" in
            --user)
                SERVICE_TYPE="user"
                shift
                ;;
            --system)
                SERVICE_TYPE="system"
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                usage
                ;;
        esac
    done
fi

# Check if systemd is available
if ! command -v systemctl &> /dev/null; then
    echo -e "${RED}Error: systemctl not found. This script requires systemd.${NC}" >&2
    exit 1
fi

# Check if milton command is available
MILTON_CMD=$(command -v milton 2>/dev/null || echo "")
if [ -z "$MILTON_CMD" ]; then
    echo -e "${YELLOW}Warning: 'milton' command not found in PATH.${NC}" >&2
    echo "Please ensure milton is installed and in your PATH, or edit the service file manually."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}Found milton command: $MILTON_CMD${NC}"
fi

# Determine MILTON_BASE
if [ -n "$MILTON_BASE" ]; then
    MILTON_BASE_DIR="$MILTON_BASE"
elif [ -n "$MILTON_CMD" ]; then
    # Try to determine from milton command location
    MILTON_DIR=$(dirname "$MILTON_CMD")
    if [ "$MILTON_DIR" = "/usr/bin" ] || [ "$MILTON_DIR" = "/usr/local/bin" ]; then
        MILTON_BASE_DIR="/usr"
    elif [ "$MILTON_DIR" = "/opt/milton/bin" ]; then
        MILTON_BASE_DIR="/opt/milton"
    else
        MILTON_BASE_DIR=$(dirname "$MILTON_DIR")
    fi
else
    # Default guess
    if [ -d "$HOME/.local/milton" ]; then
        MILTON_BASE_DIR="$HOME/.local/milton"
    elif [ -d "/opt/milton" ]; then
        MILTON_BASE_DIR="/opt/milton"
    else
        MILTON_BASE_DIR=""
    fi
fi

if [ -n "$MILTON_BASE_DIR" ]; then
    echo -e "${GREEN}Detected MILTON_BASE: $MILTON_BASE_DIR${NC}"
else
    echo -e "${YELLOW}Warning: Could not determine MILTON_BASE.${NC}"
    echo "You will need to set this in the service file manually."
fi

# Install user service
if [ "$SERVICE_TYPE" = "user" ]; then
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}Error: User services should not be installed as root.${NC}" >&2
        echo "Run this script as a regular user, or use --system for system services."
        exit 1
    fi
    
    USER_SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$USER_SERVICE_DIR"
    
    echo -e "${GREEN}Installing user service to $USER_SERVICE_DIR${NC}"
    
    # Copy and customize service file
    cp "$SCRIPT_DIR/milton-user.service" "$USER_SERVICE_DIR/milton-user.service"
    
    # Update MILTON_BASE if we detected it
    if [ -n "$MILTON_BASE_DIR" ]; then
        sed -i "s|Environment=\"MILTON_BASE=.*\"|Environment=\"MILTON_BASE=$MILTON_BASE_DIR\"|" \
            "$USER_SERVICE_DIR/milton-user.service"
        # Update PATH to include milton bin directory
        if [ -d "$MILTON_BASE_DIR/bin" ]; then
            sed -i "s|Environment=\"PATH=.*\"|Environment=\"PATH=$MILTON_BASE_DIR/bin:/usr/local/bin:/usr/bin:/bin\"|" \
                "$USER_SERVICE_DIR/milton-user.service"
        fi
    fi
    
    echo -e "${GREEN}Service file installed.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Edit the service file if needed: nano $USER_SERVICE_DIR/milton-user.service"
    echo "  2. Reload systemd: systemctl --user daemon-reload"
    echo "  3. Enable the service: systemctl --user enable milton-user.service"
    echo "  4. Start the service: systemctl --user start milton-user.service"
    echo "  5. Check status: systemctl --user status milton-user.service"
    echo ""
    echo "To enable the service to start at login: loginctl enable-linger $USER"
    
# Install system service
elif [ "$SERVICE_TYPE" = "system" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: System services require sudo privileges.${NC}" >&2
        echo "Run: sudo $0 --system"
        exit 1
    fi
    
    SYSTEM_SERVICE_DIR="/etc/systemd/system"
    
    echo -e "${GREEN}Installing system service to $SYSTEM_SERVICE_DIR${NC}"
    
    # Copy service file
    cp "$SCRIPT_DIR/milton.service" "$SYSTEM_SERVICE_DIR/milton.service"
    
    # Update MILTON_BASE if we detected it
    if [ -n "$MILTON_BASE_DIR" ]; then
        sed -i "s|# Environment=\"MILTON_BASE=.*\"|Environment=\"MILTON_BASE=$MILTON_BASE_DIR\"|" \
            "$SYSTEM_SERVICE_DIR/milton.service"
        sed -i "s|Environment=\"MILTON_BASE=.*\"|Environment=\"MILTON_BASE=$MILTON_BASE_DIR\"|" \
            "$SYSTEM_SERVICE_DIR/milton.service"
    fi
    
    echo -e "${GREEN}Service file installed.${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: You must edit the service file before enabling it!${NC}"
    echo "  1. Edit the service file: nano $SYSTEM_SERVICE_DIR/milton.service"
    echo "     - Set User= to the desired user account"
    echo "     - Set Group= to the desired group"
    echo "     - Set WorkingDirectory to the configuration directory"
    echo "     - Verify MILTON_BASE is correct"
    echo "  2. Reload systemd: systemctl daemon-reload"
    echo "  3. Enable the service: systemctl enable milton.service"
    echo "  4. Start the service: systemctl start milton.service"
    echo "  5. Check status: systemctl status milton.service"
    
else
    echo -e "${RED}Error: Unknown service type: $SERVICE_TYPE${NC}" >&2
    exit 1
fi

