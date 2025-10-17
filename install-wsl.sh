#!/usr/bin/env bash
#
# Install script for cdp (WSL/Linux version)
#
# This script installs the cdp shell functions for bash/zsh in WSL or Linux environments.
# It can automatically install fzf and jq if they are not present.
#
# Usage:
#   ./install-wsl.sh              # Install for current user
#   ./install-wsl.sh --auto       # Auto-install dependencies without prompts
#
# One-liner install (from GitHub):
#   bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Configuration
AUTO_INSTALL=false
INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.cdp"
SCRIPT_NAME="cdp.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/GoldenZqqq/cdp/main/src/cdp.sh"
USE_REMOTE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --auto)
            AUTO_INSTALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto        Auto-install dependencies without prompts"
            echo "  --help, -h    Show this help message"
            exit 0
            ;;
    esac
done

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists brew; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Function to install package
install_package() {
    local package="$1"
    local pm=$(detect_package_manager)

    echo -e "${CYAN}Installing $package...${NC}"

    case $pm in
        apt)
            sudo apt-get update && sudo apt-get install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        yum)
            sudo yum install -y "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package"
            ;;
        brew)
            brew install "$package"
            ;;
        *)
            echo -e "${RED}Error: Could not detect package manager.${NC}"
            echo -e "${YELLOW}Please install $package manually.${NC}"
            return 1
            ;;
    esac
}

# Check and install fzf
check_and_install_fzf() {
    if ! command_exists fzf; then
        echo -e "${YELLOW}fzf is not installed.${NC}"

        if [[ "$AUTO_INSTALL" == true ]]; then
            install_package fzf
        else
            echo -e "${CYAN}Would you like to install fzf now? (y/N)${NC}"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                install_package fzf
            else
                echo -e "${RED}Error: fzf is required for cdp to work.${NC}"
                echo -e "${CYAN}Please install it manually:${NC}"
                echo -e "${CYAN}  Ubuntu/Debian: sudo apt install fzf${NC}"
                echo -e "${CYAN}  Fedora: sudo dnf install fzf${NC}"
                echo -e "${CYAN}  Arch: sudo pacman -S fzf${NC}"
                echo -e "${CYAN}  macOS: brew install fzf${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✓ fzf is already installed${NC}"
    fi
}

# Check and install jq
check_and_install_jq() {
    if ! command_exists jq; then
        echo -e "${YELLOW}jq is not installed.${NC}"

        if [[ "$AUTO_INSTALL" == true ]]; then
            install_package jq
        else
            echo -e "${CYAN}Would you like to install jq now? (y/N)${NC}"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                install_package jq
            else
                echo -e "${RED}Error: jq is required for cdp to work.${NC}"
                echo -e "${CYAN}Please install it manually:${NC}"
                echo -e "${CYAN}  Ubuntu/Debian: sudo apt install jq${NC}"
                echo -e "${CYAN}  Fedora: sudo dnf install jq${NC}"
                echo -e "${CYAN}  Arch: sudo pacman -S jq${NC}"
                echo -e "${CYAN}  macOS: brew install jq${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✓ jq is already installed${NC}"
    fi
}

# Main installation
echo -e "${CYAN}=== cdp WSL/Linux Installer ===${NC}"
echo ""

# Check dependencies
echo -e "${CYAN}Checking dependencies...${NC}"
check_and_install_fzf
check_and_install_jq
echo ""

# Create installation directory
echo -e "${CYAN}Creating installation directory...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2>/dev/null && pwd )"

# If script directory is empty or script is piped from curl, download from GitHub
if [[ -z "$SCRIPT_DIR" ]] || [[ ! -d "$SCRIPT_DIR" ]]; then
    USE_REMOTE=true
fi

# Copy cdp script
echo -e "${CYAN}Installing cdp script...${NC}"

if [[ "$USE_REMOTE" == true ]]; then
    # Download from GitHub
    echo -e "${CYAN}Downloading cdp.sh from GitHub...${NC}"
    if command_exists curl; then
        curl -fsSL "$GITHUB_RAW_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
    elif command_exists wget; then
        wget -q "$GITHUB_RAW_URL" -O "$INSTALL_DIR/$SCRIPT_NAME"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        exit 1
    fi
else
    # Copy from local directory
    if [[ -f "$SCRIPT_DIR/src/$SCRIPT_NAME" ]]; then
        cp "$SCRIPT_DIR/src/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
    elif [[ -f "$SCRIPT_DIR/$SCRIPT_NAME" ]]; then
        cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
    else
        echo -e "${RED}Error: Could not find $SCRIPT_NAME${NC}"
        exit 1
    fi
fi

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo -e "${GREEN}✓ Installed to $INSTALL_DIR/$SCRIPT_NAME${NC}"
echo ""

# Detect shell
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    *)
        echo -e "${YELLOW}Warning: Unknown shell '$SHELL_NAME'. Please add the source line manually.${NC}"
        RC_FILE=""
        ;;
esac

# Add to shell RC file
if [[ -n "$RC_FILE" ]]; then
    SOURCE_LINE="source \"$INSTALL_DIR/$SCRIPT_NAME\""

    if grep -qF "$SOURCE_LINE" "$RC_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ Already configured in $RC_FILE${NC}"
    else
        echo -e "${CYAN}Adding cdp to $RC_FILE...${NC}"

        # Add configuration block
        {
            echo ""
            echo "# cdp - Fast project directory switcher"
            echo "$SOURCE_LINE"
        } >> "$RC_FILE"

        echo -e "${GREEN}✓ Added to $RC_FILE${NC}"
    fi
fi

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"

    if [[ -n "$RC_FILE" ]] && ! grep -qF "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$RC_FILE" 2>/dev/null; then
        echo -e "${CYAN}Adding $INSTALL_DIR to PATH in $RC_FILE...${NC}"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$RC_FILE"
        echo -e "${GREEN}✓ Added to PATH${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Installation complete! ===${NC}"
echo ""
echo -e "${CYAN}To start using cdp, either:${NC}"
echo -e "  1. Restart your terminal, or"
echo -e "  2. Run: ${YELLOW}source $RC_FILE${NC}"
echo ""
echo -e "${CYAN}Quick start:${NC}"
echo -e "  ${YELLOW}cdp${NC}          - Select and switch to a project"
echo -e "  ${YELLOW}cdp-add${NC}      - Add current directory as a project"
echo -e "  ${YELLOW}cdp-ls${NC}       - List all enabled projects"
echo ""
echo -e "${CYAN}Configuration file:${NC} $CONFIG_DIR/projects.json"
echo -e "${GRAY}(Shares config with PowerShell version if using Project Manager)${NC}"
echo ""
