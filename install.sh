#!/usr/bin/env bash
set -euo pipefail

# Simple cross-platform installer: detects OS, installs Python and pip,
# then installs dependencies from a requirements file.
#
# Usage:
#   curl -fsSL https://.../install.sh | bash -s -- [OPTIONS]
#   ./install.sh [OPTIONS]
#
# Options:
#   --yes                 Non-interactive; answer 'yes' to prompts (use with care).
#   --venv                Create and use a local virtual environment (.venv) before installing deps.
#   --requirements FILE   Path to requirements file (default: ./requirements.txt).
#   -h, --help            Show help

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}==>${NC} $*"; }
info()  { echo -e "${BLUE}   $*${NC}"; }
warn()  { echo -e "${YELLOW}warning:${NC} $*" >&2; }
error() { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

NONINTERACTIVE=false
USE_VENV=false
REQUIREMENTS_FILE="requirements.txt"

usage() {
    cat <<EOF
install.sh - install Python and Python dependencies

Usage:
  bash install.sh [OPTIONS]

Options:
  --yes                 Non-interactive (assume yes for prompts)
  --venv                Create/use .venv and install into it
  --requirements FILE   Path to requirements file (default: ./requirements.txt)
  -h, --help            Show this help

This script supports macOS and common Linux distros. It will attempt to
install Python3 and pip via the detected package manager, then install
Python dependencies from the requirements file.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes)
                NONINTERACTIVE=true; shift ;;
            --venv)
                USE_VENV=true; shift ;;
            --requirements)
                REQUIREMENTS_FILE="${2:-}"; shift 2 ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                error "Unknown option: $1" ;;
        esac
    done
}

detect_platform() {
    uname_s=$(uname -s)
    uname_m=$(uname -m)

    case "$uname_s" in
        Darwin*) OS="macos" ;;
        Linux*)  OS="linux" ;;
        MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
        *)       OS="unknown" ;;
    esac

    case "$uname_m" in
        x86_64|amd64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) ARCH="$uname_m" ;;
    esac

    info "Detected platform: $OS/$ARCH"
}

detect_distro_and_pkgmgr() {
    PKG_MANAGER=""
    DISTRO=""
    if [[ "$OS" == "linux" ]]; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release || true
            DISTRO=${ID:-${NAME:-"linux"}}
        fi

        if command_exists apt-get; then
            PKG_MANAGER="apt"
        elif command_exists dnf; then
            PKG_MANAGER="dnf"
        elif command_exists yum; then
            PKG_MANAGER="yum"
        elif command_exists pacman; then
            PKG_MANAGER="pacman"
        elif command_exists zypper; then
            PKG_MANAGER="zypper"
        fi
    elif [[ "$OS" == "macos" ]]; then
        if command_exists brew; then
            PKG_MANAGER="brew"
        else
            PKG_MANAGER="brew-missing"
        fi
    elif [[ "$OS" == "windows" ]]; then
        # Running under Git Bash / MSYS / Cygwin on Windows
        if command_exists choco; then
            PKG_MANAGER="choco"
        elif command_exists scoop; then
            PKG_MANAGER="scoop"
        elif command_exists winget || command_exists powershell.exe; then
            PKG_MANAGER="winget"
        else
            PKG_MANAGER="windows-unknown"
        fi
    fi

    info "Package manager: ${PKG_MANAGER:-unknown}"
}

confirm() {
    if $NONINTERACTIVE; then
        return 0
    fi
    read -r -p "$1 [y/N]: " ans
    case "$ans" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

install_python_macos() {
    if command_exists python3; then
        info "python3 already installed"
        return 0
    fi

    if [[ "$PKG_MANAGER" == "brew" ]]; then
        log "Installing Python via Homebrew..."
        brew update || true
        brew install python || error "brew install python failed"
        return 0
    fi

    warn "Homebrew not found. Please install Homebrew (https://brew.sh/) or install Python manually."
    if confirm "Attempt to install Homebrew now?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || warn "Homebrew installer failed"
        if command_exists brew; then
            brew update || true
            brew install python || error "brew install python failed"
            return 0
        else
            error "Homebrew installation failed. Please install Python manually."
        fi
    else
        error "Aborting: Python3 is required."
    fi
}

install_python_linux() {
    if command_exists python3; then
        info "python3 already installed"
        return 0
    fi

    if [[ -z "$PKG_MANAGER" ]]; then
        error "No supported package manager detected. Install Python3 manually."
    fi

    log "Installing Python3 via $PKG_MANAGER..."
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -y
            sudo apt-get install -y python3 python3-venv python3-pip
            ;;
        dnf)
            sudo dnf install -y python3 python3-venv python3-pip
            ;;
        yum)
            sudo yum install -y python3
            ;;
        pacman)
            sudo pacman -Syu --noconfirm python python-pip
            ;;
        zypper)
            sudo zypper install -y python3 python3-pip
            ;;
        *)
            error "Unsupported package manager: $PKG_MANAGER"
            ;;
    esac
}

install_python_windows() {
    if command_exists python3 || command_exists python; then
        info "python already installed"
        return 0
    fi

    log "Installing Python on Windows (Git Bash/Cygwin)..."

    if [[ "$PKG_MANAGER" == "choco" ]]; then
        if command_exists choco; then
            choco install -y python || warn "choco python install failed"
            return 0
        fi
    fi

    if [[ "$PKG_MANAGER" == "scoop" ]]; then
        if command_exists scoop; then
            scoop install python || warn "scoop python install failed"
            return 0
        fi
    fi

    # Try winget via powershell if available
    if command_exists powershell.exe; then
        warn "Attempting winget install via PowerShell (may require elevation)."
        powershell.exe -NoProfile -Command \
            "try { winget install --id Python.Python.3 -e --accept-package-agreements --accept-source-agreements } catch { exit 1 }" || warn "winget failed or not available"
        # Refresh shell's view: user may need to open a new shell
        return 0
    fi

    warn "No Windows package manager found (choco, scoop, winget). Please install Python manually from https://www.python.org/downloads/."
}

ensure_pip() {
    if command_exists pip3; then
        PIP_CMD="pip3"
    elif python3 -m pip --version >/dev/null 2>&1; then
        PIP_CMD="python3 -m pip"
    elif command_exists pip; then
        PIP_CMD="pip"
    else
        warn "pip not found. Attempting to bootstrap pip..."
        python3 -m ensurepip --upgrade || python3 -m pip install --upgrade pip || true
        if python3 -m pip --version >/dev/null 2>&1; then
            PIP_CMD="python3 -m pip"
        else
            error "pip installation failed. Install pip manually."
        fi
    fi

    info "Using pip command: $PIP_CMD"
}

fetch_requirements() {
    # If REQUIREMENTS_FILE is an HTTP(S) URL, download it to a temp file
    REQ_LOCAL=""
    if [[ "$REQUIREMENTS_FILE" =~ ^https?:// ]]; then
        if ! command_exists curl && ! command_exists wget; then
            error "curl or wget is required to download remote requirements file"
        fi

        tmp_req=$(mktemp)
        # ensure temp file cleaned up on exit
        trap '[[ -n "${tmp_req:-}" ]] && rm -f "$tmp_req"' EXIT

        info "Downloading requirements from: $REQUIREMENTS_FILE"
        if command_exists curl; then
            curl -fsSL "$REQUIREMENTS_FILE" -o "$tmp_req" || { rm -f "$tmp_req"; error "Failed to download $REQUIREMENTS_FILE"; }
        else
            wget -q -O "$tmp_req" "$REQUIREMENTS_FILE" || { rm -f "$tmp_req"; error "Failed to download $REQUIREMENTS_FILE"; }
        fi

        REQ_LOCAL="$tmp_req"
    else
        REQ_LOCAL="$REQUIREMENTS_FILE"
    fi
}

install_dependencies() {
    fetch_requirements

    if [[ ! -f "$REQ_LOCAL" ]]; then
        warn "Requirements file not found: $REQUIREMENTS_FILE. Skipping dependency installation."
        return 0
    fi

    ensure_pip

    if $USE_VENV; then
        info "Creating virtualenv in .venv"
        python3 -m venv .venv
        # shellcheck disable=SC1091
        source .venv/bin/activate
        $PIP_CMD install --upgrade pip
        $PIP_CMD install -r "$REQ_LOCAL"
        info "Dependencies installed into .venv"
    else
        info "Installing dependencies for current user (pip --user)"
        # Expand PIP_CMD if it's a compound command
        if [[ "$PIP_CMD" == "python3 -m pip" ]]; then
            python3 -m pip install --user --upgrade pip
            python3 -m pip install --user -r "$REQ_LOCAL"
        else
            $PIP_CMD install --user --upgrade pip
            $PIP_CMD install --user -r "$REQ_LOCAL"
        fi
        info "Dependencies installed (user site-packages)"
    fi

    # If we downloaded a temporary requirements file, leave trap to remove it on exit
}

main() {
    parse_args "$@"
    detect_platform
    detect_distro_and_pkgmgr

    if [[ "$OS" == "unknown" ]]; then
        error "Unsupported OS. This script supports macOS and Linux."
    fi

    # Install Python if needed
    if ! command_exists python3 && ! command_exists python; then
        if [[ "$OS" == "macos" ]]; then
            install_python_macos
        elif [[ "$OS" == "linux" ]]; then
            install_python_linux
        elif [[ "$OS" == "windows" ]]; then
            install_python_windows
        fi
    else
        # Prefer python3 but fall back to python
        if command_exists python3; then
            info "python3 already present: $(python3 --version 2>/dev/null || true)"
        else
            info "python present: $(python --version 2>/dev/null || true)"
        fi
    fi

    # Upgrade pip and install dependencies
    install_dependencies

    echo
    log "Done"
    info "To activate the venv (if used): source .venv/bin/activate"
    if [[ "$USE_VENV" == true ]]; then
        info "Virtualenv created at: $(pwd)/.venv"
    fi
    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        info "Installed requirements from: $REQUIREMENTS_FILE"
    fi
}

main "$@"
