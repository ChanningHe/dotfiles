#!/usr/bin/env bash
# Dotfiles installation script
# Reads dotfiles.toml and creates symlinks
#
# Usage:
#   ./getdots.sh                    # Install all dotfiles
#   ./getdots.sh -i nvim p10k       # Install specific dotfiles
#   ./getdots.sh -l                 # List available dotfiles
#   ./getdots.sh --help             # Show help

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/dotfiles.toml"

# Logging functions
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
${BLUE}Dotfiles Installation Script${NC}

Usage: $0 [OPTIONS] [-i COMPONENT...]

Options:
  -h, --help       Show this help message
  -l, --list       List available dotfiles from config
  -n, --dry-run    Show what would be done without making changes
  -f, --force      Overwrite existing files without backup
  -i, --install    Install specific components (space-separated)

Examples:
  $0                    # Install all dotfiles
  $0 -i nvim            # Install only nvim
  $0 -i nvim p10k       # Install nvim and p10k
  $0 -n -i nvim         # Dry run for nvim
  $0 -l                 # List available dotfiles
EOF
}

# Parse TOML and extract dotfiles entries
# Returns: name|source|target (one per line)
parse_toml() {
    local current_name=""
    local current_source=""
    local current_target=""

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Match section header [name]
        if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
            # Output previous entry if complete
            if [[ -n "$current_name" && -n "$current_source" && -n "$current_target" ]]; then
                echo "${current_name}|${current_source}|${current_target}"
            fi
            current_name="${BASH_REMATCH[1]}"
            current_source=""
            current_target=""
        # Match source = "value"
        elif [[ "$line" =~ ^[[:space:]]*source[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
            current_source="${BASH_REMATCH[1]}"
        # Match target = "value"
        elif [[ "$line" =~ ^[[:space:]]*target[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
            current_target="${BASH_REMATCH[1]}"
        fi
    done < "$CONFIG_FILE"

    # Output last entry
    if [[ -n "$current_name" && -n "$current_source" && -n "$current_target" ]]; then
        echo "${current_name}|${current_source}|${current_target}"
    fi
}

# List available dotfiles
list_dotfiles() {
    echo -e "${BLUE}Available dotfiles:${NC}"
    echo ""
    printf "  %-12s %-20s -> %s\n" "NAME" "SOURCE" "TARGET"
    printf "  %-12s %-20s    %s\n" "----" "------" "------"
    
    while IFS='|' read -r name source target; do
        printf "  %-12s %-20s -> ~/%s\n" "$name" "$source" "$target"
    done < <(parse_toml)
}

# Create symlink with backup support
create_link() {
    local source="$1"
    local target="$2"
    local dry_run="${DRY_RUN:-false}"
    local force="${FORCE:-false}"

    # Check source exists
    if [[ ! -e "$source" ]]; then
        log_error "Source not found: $source"
        return 1
    fi

    # Handle existing target
    if [[ -L "$target" ]]; then
        local current_link
        current_link=$(readlink "$target")
        if [[ "$current_link" == "$source" ]]; then
            log_success "Already linked: $target"
            return 0
        else
            log_info "Updating symlink: $target"
            [[ "$dry_run" != "true" ]] && rm "$target"
        fi
    elif [[ -e "$target" ]]; then
        if [[ "$force" == "true" ]]; then
            log_warn "Removing existing: $target"
            [[ "$dry_run" != "true" ]] && rm -rf "$target"
        else
            local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
            log_warn "Backing up: $target -> $backup"
            [[ "$dry_run" != "true" ]] && mv "$target" "$backup"
        fi
    fi

    # Create parent directory
    local parent_dir
    parent_dir=$(dirname "$target")
    if [[ ! -d "$parent_dir" ]]; then
        [[ "$dry_run" == "true" ]] && echo "  Would create: $parent_dir"
        [[ "$dry_run" != "true" ]] && mkdir -p "$parent_dir"
    fi

    # Create symlink
    if [[ "$dry_run" == "true" ]]; then
        echo "  Would link: $target -> $source"
    else
        ln -s "$source" "$target"
        log_success "Linked: $target -> $source"
    fi
}

# Install a single dotfile by name
install_dotfile() {
    local name="$1"
    local found=false

    while IFS='|' read -r entry_name source target; do
        if [[ "$entry_name" == "$name" ]]; then
            found=true
            local full_source="${SCRIPT_DIR}/${source}"
            local full_target="${HOME}/${target}"
            
            log_info "Installing ${name}..."
            create_link "$full_source" "$full_target"
            break
        fi
    done < <(parse_toml)

    if [[ "$found" == "false" ]]; then
        log_error "Unknown dotfile: $name"
        echo "Run '$0 -l' to see available dotfiles"
        return 1
    fi
}

# Install all dotfiles
install_all() {
    while IFS='|' read -r name source target; do
        local full_source="${SCRIPT_DIR}/${source}"
        local full_target="${HOME}/${target}"
        
        log_info "Installing ${name}..."
        create_link "$full_source" "$full_target"
    done < <(parse_toml)
}

# Main
main() {
    local components=()
    local list_only=false
    DRY_RUN=false
    FORCE=false

    # Check config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -i|--install)
                shift
                # Collect all following non-option arguments
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    components+=("$1")
                    shift
                done
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # Positional args after -i
                components+=("$1")
                shift
                ;;
        esac
    done

    export DRY_RUN FORCE

    # List mode
    if [[ "$list_only" == "true" ]]; then
        list_dotfiles
        exit 0
    fi

    # Header
    echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Dotfiles Installation          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
    echo ""
    log_info "Source: $SCRIPT_DIR"
    log_info "Config: $CONFIG_FILE"
    [[ "$DRY_RUN" == "true" ]] && log_warn "Dry run mode - no changes will be made"
    echo ""

    # Install
    if [[ ${#components[@]} -eq 0 ]]; then
        install_all
    else
        for name in "${components[@]}"; do
            install_dotfile "$name"
        done
    fi

    echo ""
    log_success "Installation complete!"
}

main "$@"
