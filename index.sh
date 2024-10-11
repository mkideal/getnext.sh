#!/usr/bin/env sh

set -eu

# Check if the terminal supports colors
supports_color() {
    if [ -t 1 ]; then
        ncolors=$(tput colors)
        if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
            return 0
        fi
    fi
    return 1
}

# Set color variables based on terminal support
if supports_color; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;94m'  # Light blue
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Print formatted messages
print_step() {
    echo "${GREEN}${BOLD}$1${NC}"
}

print_sub_step() {
    echo "  $1"
}

align() {
    local _indent=$1
    local _text=$2
    local cols=$(tput cols)
    if [ "$cols" -gt 80 ]; then
        cols=100
    fi
    echo "$_text" | fold -s -w $((cols - _indent)) | sed -e "2,\$s/^/$(printf '%*s' $_indent '')/"
}

# Print success message
success() {
    local _prefix="${GREEN}Success: ${NC}"
    local _prefix_length=9  # Length of "Success: " without color codes
    local _msg="$*"
    printf "\n$_prefix"
    align $_prefix_length "$_msg"
}

# Print information message
info() {
    local _msg="$*"
    align 0 "$_msg"
}

# Print warning message
warn() {
    local _prefix="${YELLOW}Warning: ${NC}"
    local _prefix_length=9  # Length of "Warning: " without color codes
    local _msg="$*"
    printf "$_prefix"
    align $_prefix_length "$_msg"
}

# Print error message
error() {
    local prefix="${RED}${BOLD}Error: ${NC}"
    local prefix_length=7  # Length of "Error: " without color codes
    local msg="$*"
    printf "$prefix"
    align $prefix_length "$msg"
}

die() {
    error $*
    exit 1
}

# Initialize variables
PREFIX=""
VERSION=""

# Function to print help message
print_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --prefix=PREFIX    Specify the installation prefix (must be an absolute path)
  --version=VERSION  Specify the version to install
  --help             Display this help message

By default, the script installs the latest version of Next to \$HOME/.local (on Linux) or \$HOME (on other systems).
EOF
}

# Parse command-line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --prefix=*)
            PREFIX="${1#--prefix=}"
            # Check if PREFIX is an absolute path
            case "$PREFIX" in
                /*) ;;
                *)
                    die "PREFIX must be an absolute path. Received: $PREFIX"
                    ;;
            esac
            shift
            ;;
        --version=*)
            VERSION="${1#--version=}"
            shift
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            error "unknown option $1"
            print_help
            exit 1
            ;;
    esac
done

# Detect OS and architecture
detect_os_arch() {
    print_step "Detecting system information"
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [[ "$OS" == "mingw"* ]]; then
        OS="mingw"
    fi
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        i386|i486|i586|i686|x86) ARCH="386" ;;
        *) die "Unsupported architecture: $ARCH" ;;
    esac
    case $OS in
        linux|darwin) ;;
        windows*|Windows*) OS="windows" ;;
        *) die "Unsupported operating system: $OS" ;;
    esac
    print_sub_step "Detected OS: ${BOLD}$OS${NC}"
    print_sub_step "Detected architecture: ${BOLD}$ARCH${NC}"
}

# Set default binary and config directories based on OS
set_default_dirs() {
    print_step "Setting up installation directories"
    if [ -z "$PREFIX" ]; then
        if [ "$OS" = "linux" ]; then
            PREFIX="$HOME/.local"
        else
            PREFIX="$HOME"
        fi
    fi
    BIN_DIR="$PREFIX/bin"
    print_sub_step "Binary directory: ${BOLD}$BIN_DIR${NC}"
}

# Get the latest stable version
get_latest_version() {
    local _url="https://api.github.com/repos/mkideal/next/releases/latest"
    print_step "Fetching latest version information"
    print_sub_step "URL: $_url"
    LATEST_VERSION=$(curl -sSf $_url | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_VERSION" ]; then
        die "Failed to get the latest version. Please check your internet connection or try again later."
    fi
    LATEST_VERSION=${LATEST_VERSION#v} # Remove 'v' prefix if present
    print_sub_step "Latest version: ${BOLD}$LATEST_VERSION${NC}"
}

# Download the appropriate Next package
download_next() {
    VERSION=${VERSION:-$LATEST_VERSION}
    FILENAME="next.$VERSION.$OS-$ARCH.tar.gz"
    URL="https://github.com/mkideal/next/releases/download/v$VERSION/$FILENAME"

    print_step "Downloading Next package"
    print_sub_step "URL: $URL"

    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    if [ $? -ne 0 ]; then
        die "Failed to create temporary directory"
    fi

    # Download the Next package
    if command -v wget > /dev/null 2>&1; then
        if ! wget -q --show-progress --progress=bar:force:noscroll -O "$TEMP_DIR/$FILENAME" "$URL"; then
            rm -rf "$TEMP_DIR"
            die "Failed to download Next. Please check your internet connection and try again."
        fi
    else
        if ! curl -fSL --progress-bar "$URL" -o "$TEMP_DIR/$FILENAME"; then
            rm -rf "$TEMP_DIR"
            die "Failed to download Next. Please check your internet connection and try again."
        fi
    fi

    # Set the TEMP_DIR variable for use in the install_next function
    DOWNLOAD_DIR="$TEMP_DIR"
    print_sub_step "Download completed successfully"
}

# Install Next
install_next() {
    print_step "Installing Next"
    if ! tar -xzf "$DOWNLOAD_DIR/next.$VERSION.$OS-$ARCH.tar.gz" -C "$DOWNLOAD_DIR"; then
        rm -rf "$DOWNLOAD_DIR"
        die "Failed to extract Next package."
    fi

    mkdir -p "$BIN_DIR" || die "Failed to create installation directory $BIN_DIR"

    mv "$DOWNLOAD_DIR/next.$VERSION.$OS-$ARCH/bin/"* "$BIN_DIR/" || die "Failed to install Next binary."

    # Clean up the temporary directory
    rm -rf "$DOWNLOAD_DIR"

    success "Next has been successfully installed!"
}

# Check if the installation directory is in PATH
check_path() {
    print_step "Checking PATH configuration"
    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
        warn "Installation directory is not in your PATH."
        info "Add the following line to your shell configuration file (.bashrc, .zshrc, etc.):"
        info "${MAGENTA}export PATH=\"\$PATH:$BIN_DIR\"${NC}"
    else
        print_sub_step "Installation directory is already in PATH"
    fi
}

# Display countdown
countdown() {
    local _fmt="${YELLOW}Installation will start in ${BOLD}%d${NC}${YELLOW} seconds. Press Ctrl+C to cancel.${NC}"
    printf "${_fmt}" 5
    for i in 4 3 2 1; do
        sleep 1
        printf "\r${_fmt}" $i
    done
    printf "\r%*s\r" $(tput cols) ""
}

# Print welcome message in a box
print_welcome() {
    message="Welcome to the Next Installer"
    padding="  "
    width=$(( $(printf "%s" "$message" | wc -c) + $(printf "%s" "$padding" | wc -c) * 2 ))

    print_line() {
        i=1
        while [ $i -le "$1" ]; do
            printf "%s" "─"
            i=$((i + 1))
        done
    }

    printf '╭'
    print_line "$width"
    printf '╮\n'
    
    printf '│%s%b%s%b%s│\n' "$padding" "$BOLD" "$message" "$NC" "$padding"
    
    printf '╰'
    print_line "$width"
    printf '╯'
    printf '%b\n\n' "$NC"
}

# Main installation process
main() {
    print_welcome

    detect_os_arch
    set_default_dirs

    if [ -z "$VERSION" ]; then
        get_latest_version
    else
        LATEST_VERSION="$VERSION"
    fi

    info
    info "If you want to change these locations, please use the ${BOLD}--prefix=PREFIX${NC} command-line option."
    info "To install a specific version, use the ${BOLD}--version=VERSION${NC} command-line option."
    info "Use ${BOLD}--help${NC} to display this help message."
    info

    countdown

    download_next
    install_next
    check_path

    info 
    info "${BOLD}${GREEN}Installation Complete!${NC}"
    info "To start using Next, run: ${BOLD}$BIN_DIR/next${NC} or ${BOLD}next${NC} if you have added $BIN_DIR to your PATH."
}

# Run the installation
main
