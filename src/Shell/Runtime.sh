#!/usr/bin/env bash
# shellcheck shell=bash
# cdp shell domain: Runtime.sh
# Generated from the canonical cdp.sh source; do not source peer fragments.
#
# cdp - Fast project directory switcher for bash/zsh (WSL version)
#
# Compatible with VS Code/Cursor Project Manager and custom JSON configs.
# Shares the same configuration files as the PowerShell version.
#
# Author: GoldenZqqq
# Version: 2.1.0
# License: MIT

CDP_VERSION="2.1.0"

# zsh compatibility: use bash-like array indexing and regex matching
if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt KSH_ARRAYS BASH_REMATCH 2>/dev/null
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD_CYAN='\033[1;36m'
NC='\033[0m' # No Color

CDP_SAFETY_DRY_RUN=false
CDP_SAFETY_YES=false
CDP_SAFETY_ARGS=()
